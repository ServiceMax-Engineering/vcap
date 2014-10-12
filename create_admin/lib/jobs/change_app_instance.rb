require 'rubygems'

require "jobs/job"

module Jobs
  class ChangeAppInstance < Job; end
end

class ::Jobs::ChangeAppInstance
  include HttpProxy

  def initialize(options)
    @app_name = options['app']
    @num = options['num']
  end
  
  def run
    client = @admin_instance.vmc_client

    app = client.app_info(@app_name)
    match = @num.match(/([+-])?\d+/)
    return failed("Invalid number of instances '#{@num}'") unless match

    num = @num.to_i
    current_nums = app[:instances]
    new_nums = match.captures[0] ? current_nums + num : num
    return failed("There must be at least 1 instance.") if new_nums < 1
    
    return failed("Application [#{@app}] is already running #{@num} instances.") if current_nums == new_nums

    app[:instances] = new_nums
    client.update_app(@appname, app)

    completed("#{@app_name} instance number changed, now it is: #{new_nums}")
  end
end