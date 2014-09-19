require 'rubygems'
require 'clockwork'

require "create_admin/log"
require "create_admin/util"
require 'jobs/full_backup_job'
require 'dataservice/postgres_ds'

class ScheduledBackup
  include DataService::PostgresSvc
  include ::CreateAdmin::Log

  attr_reader :schedule_start_time, :backup_failures, :backup_job_started
  @@intance = nil
  def self.instance(options = {})
    @@intance = @@intance  || ScheduledBackup.new(options)
  end

  def bootstrap_schedule()
    setting = get_backup_setting
    if (setting.nil?)
      # no system setting ?
      error("can't find the active system setting")
      clean()
      return
    end

    changed = @backup_setting.nil? || @backup_setting.period != setting.period
    
    debug "Backup setting changed => #{changed} with settings #{setting}" if changed
    
    reschedule(setting) if changed
  end
  
  def get_backup_setting
    sql = "select extract(epoch from io_backup_period), io_backup_period, io_backup_storage_space_quantity[1] from io_system_setting where io_active='t';"
    
    setting = nil
    query(sql) {|res|
      period = res.getvalue(0, 0).to_i || 0
      label = res.getvalue(0, 1)
      storage = res.getvalue(0, 2).to_i * (1024*1024) || -1
      setting = BackupSetting.new(period, label, storage)
    }

    setting
  end
  
  def flag_failure
    @backup_failures = @backup_failures + 1
  end
  
  def reset_failure
    @backup_failures = 0
  end
  
  private
  
  def initialize(options = {})
    @manifest_path = options['manifest']
    @backup_home = options['backup_home'] || "#{ENV['HOME']}/cloudfoundry/backup"
    @running_threads = []
    @backup_failures = 0
    @backup_job_started = false
  end
  
  def clean()
    @backup_setting = nil
    @running_threads.each { | thread |
      debug "Killing backup thread #{thread}"
      thread.exit
      # just wait a while, it should eventually die
      # should not wait indefinetely
      unless thread.stop?
        sleep(5)
      end

      debug "Backup thread stopped #{thread.stop?}"
    }    
    @running_threads.clear
    
    # clear all clockwork events
    Clockwork.clear!
  end
  
  def reschedule(setting)
    clean()

    # no schedule
    return if (setting.nil? || setting.period == 0)

    @backup_setting = setting
    @schedule_start_time = Time.now.to_i
    @backup_job_started = false
    schedule_backup(setting)

    Clockwork.every(1.minute, 'Check backup settings', :thread => true) {
      check_and_update_backup_settings()
    }

    @running_threads << start_clockwork_thread()
  end
  
  def start_clockwork_thread
    retry_count = 3
    th = Thread.new do
      begin
        # run clockwork
        Clockwork.run
      rescue
        error "Clock has crashed? Restarting"
        retry_count -= 1
        retry if retry_count > 0
      end
    end

    return th
  end

  def schedule_backup(setting)
    error "backup setting is .... #{setting}"
    period = setting.period
    at = setting.at
    options = {}
    options[:at] = at unless setting.at.nil?
    debug "Creating new scheduled backup for every #{setting.period} seconds at #{at}"
    Clockwork.every(period.send(:seconds), "Backup intalio", options) {
      debug "Running backup for every #{setting.label} at #{at}"
      begin
        start_backup_job(setting.identifier)
      rescue Exception => e
        error "Caught exception #{e.message}"
        error e.backtrace
      end
    }
  end

  def start_backup_job(identifier)
    housekeep_backups(identifier)

    warn "Max storage exceeded!!! Please increase max storage setting or delete old backup archives." if max_storage_exceeded?(identifier)

    job_params = {'manifest' => @manifest_path, 'suffix' => identifier}

    debug "Preparing to create backup"
    @backup_job_started = true
    
    FullBackupJob.create(job_params)
  end

  def delete_expired_backups(backups, identifier)
    lifespan = sys_setting("extract(epoch from io_backup_lifespan)", 0)
    backups.each { |filename|
      fullapth = "#{@backup_home}/#{filename}"
      time = File.stat(fullapth).mtime.to_i
      now = Time.now.to_i
      lived = now - time
      if lived > lifespan
        File.delete(fullapth)
        debug "Deleted #{filename}"
      end
    }
  end
  
  def delete_oldest_backup(backups, identifier)
    backups = Dir.glob("#{@backup_home}/*-#{identifier}.zip").sort_by{ |f| File.mtime(f) }
    if backups.size > 0
      oldest = backups[0]
      File.delete(oldest)
      debug "Deleted backup #{oldest}"
    else
      debug "No old scheduled archives found that can be deleted"
    end
  end
  
  def get_back_ups(identifier)
    backups = []
    Dir.foreach(@backup_home) { |filename|
      backups << filename if filename =~ /^\w+-\d+-\w+-\d+-\d+-#{identifier}.zip/
    }
    backups
  end
  
  def sys_setting(name, default)
    sql = "select #{name} from io_system_setting where io_active='t';"
    query(sql) {|res|
      setting = res.getvalue(0, 0).to_i || default
    }
  end

  def housekeep_backups(identifier)
    debug "Housekeeping backups for #{identifier}"

    backups = get_back_ups(identifier)
    debug "Found #{backups.size} backups for #{identifier}"
    # do cleanup
    delete_expired_backups(backups, identifier)

    while max_storage_exceeded?(identifier)
      delete_oldest_backup(backups, identifier)
    end
  end

  def max_storage_exceeded?(identifier)
    total = 0
    Dir.foreach(@backup_home) { |filename|
      total += File.size("#{@backup_home}/#{filename}") if filename =~ /-#{identifier}.zip$/
    }
    # read max from db
    max = sys_setting('io_backup_storage_space_quantity[1]', -1)
    debug "Current total backup space used #{(total/1024)/1024} Mb. Max allowed #{max} Mb"
    total > (max * 1024 * 1024)
  end

end

class BackupSetting

  attr_reader :period
  attr_reader :label
  attr_reader :at
  attr_reader :identifier
  attr_reader :storage

  def initialize(period, label, storage)
    @period = period
    @label = label
    @at = '**:00' if period >= 3600
    @storage = storage
    @identifier = 's'
  end
end

