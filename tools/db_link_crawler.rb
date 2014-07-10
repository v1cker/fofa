#!/usr/bin/env ruby
#通过数据库的body分析，来提取所有url，通过api提交到fofa（超过90天才更新）
require 'mysql2'
#require 'thread/pool'
@root_path = File.expand_path(File.dirname(__FILE__))
require "resque"
require @root_path+"/../app/jobs/module/httpmodule.rb"
require @root_path+"/../app/jobs/module/webdb2_class.rb"
require @root_path+"/../app/jobs/module/process_class.rb"
require @root_path+"/../app/jobs/module/lrlink.rb"
include Lrlink
require 'net/http'

def write_to_file(id)
  File.open(@root_path+"/id.txt", 'w') do |f|
    f.puts id
  end
end # Def end

@m = WebDb.new(@root_path+"/../config/database.yml")
@p = Processor.new(@m)
#@pool = Thread.pool(2)
@id=902660

#load id from file
File.open(@root_path+"/id.txt", 'r') {|f|
  max_id = 0
  text = f.readline
  max_id = text.strip.to_i if text
  @id = max_id if max_id>@id
}

while true
  sql = "select * from subdomain where id>#{@id} limit 10"
  r = @m.mysql.query(sql)
  if r.size>0
    hosts = []
    ids = []
    puts "===================="
    print "id: "
    r.each {|h|
      #@pool.process(h) { |h|
        #puts "======#{h['id']} -> #{h['host']}======"
        print h['id'].to_s+" "
        arr = []
        h['body'].scan(/(http[s]?:\/\/.*?)[ \/\'\"\>]/).each{|x|
          arr << hostinfo_of_url(x[0].downcase) if x[0].size>8 && x[0].include?('.')
        }
        arr.uniq.each{|a|
          hosts << a
        }
      #}
      @id=h['id']
      ids << h['id']

    }

    puts ""
    puts "host count:"+hosts.size.to_s
    if hosts.size>0
      uri = URI('http://www.fofa.so/api/addhostp')
      res = Net::HTTP.post_form(uri, 'host' => hosts.uniq!.join(','))
      #puts "id:"+ids.join(",")
      puts "response:"+res.body
    end
    write_to_file ids.max
    #curl_line = "curl http://www.fofa.so/api/addhost?host=#{hosts.uniq.join(',')} >/dev/null 2>&1"
    #puts curl_line
    #`#{curl_line}`
  else
    break
  end

end
