#!/usr/bin/env ruby
require 'xmlrpc/client'
require 'cgi'
require 'yaml/store'
require "optparse"

### Language comment table
ONELINE_COMMENT = {
  :actionscript => '//',
  :mysql => '/*{comment}*/',
  :css => '/*{comment}*/',
  :apache       => '#',
  :applescript  => '--',
  :autoit       => ';',
  :awk          => '#',
  :c            => '/*',
  :clojure      => ';',
  :diff         => '#',
  :django       => '<!--',
  :gnuplot      => '#',
  :groovy       => '//',
  :haml         => '-#',
  :haskell      => '{-',
  :java         => '//',
  :javascript   => '//',
  :lisp         => ';',
  :lua          => '--',
  :matlab       => '%',
  :mel          => '//',
  :pascal       => '{',
  :php          => '//',
  :plsql        => '--',
  :python       => '#',
  :processing   => '//',
  :prolog       => '%',
  :r            => '#',
  :sass         => '//',
  :scala        => '//',
  :smarty       => '{*',
  :sml          => '(*',
  :sql          => '--',
  :tcl          => '#',
  :vhdl         => '--',
}
VIM_FT_LIST = {
  "sh" => %w[ bash ],
  "ruby" => %w[ rails ],
}

NOTVALID=0
class Server
  def self.open_session(key)
    server = XMLRPC::Client.new( "snipplr.com", "/xml-rpc.php")
    puts "#{} not valid API Key" and return if server.call("user.checkkey", key)==NOTVALID    
    begin
      yield server
    rescue XMLRPC::FaultException => err
      if err.faultString =~ /No snippets found/ 
        puts "No snippets yet!" 
      else 
        puts "Error: " + err.faultCode.to_s + ", " + err.faultString
      end
    end
  end
end

class Snipplr
  def initialize
    @db = YAML::Store.new(DB_PATH)
  end

  def get(req)
    nocache = OPT[:nocache]

    match =  %r{http://snipplr.com/view/(\d+)/}.match(req)
    if match
      id = match[1]
    else
      id  = req.chomp
    end

    unless nocache
      snip = db_read id
    end

    unless snip
      Server.open_session($key) do |server|
        snip = server.call("snippet.get", id.to_s)
      end
      return snip if snip.nil?
      db_update snip
    end
    snip["source"] = CGI::unescapeHTML(snip["source"])
    snip["comment"] = CGI::unescapeHTML(snip["comment"])
    return snip
  end

  def info(id)
    result = []
    snip = db_read id 
    unless snip
      get id
      snip = db_read id
    end
    return "Snippet #{id} not exist" if snip.nil?

    snip["comment"] = CGI::unescapeHTML(snip["comment"])
    #["id","title","comment", "snipplr_url", "language", "username", "tags", "updated", "created"].each do |e|
    ["id","title","language","tags","username","comment", "snipplr_url"  ].each do |e|
      result << "[%-11s]: %s" % [e, snip[e]]
    end
    return result
  end

  def list
    unless OPT[:nocache]
      list_local
    else
      list_remote
    end
  end

  def list_local
    result = []

    @db.transaction do |db|
      db.roots.each  do |id|
        e = db[id]
        if OPT[:lang]
          next unless e["language"].downcase =~ /#{OPT[:lang].downcase}/
        end
        result << e
      end
    end
    r = result.sort_by { |e| e["id"].to_i }.map do |ent|
       "%6s [%s] %s" % [ent["id"], ent["language"],ent["title"]]
    end
    return r
  end

  def list_remote
    result = []
    Server.open_session($key) do |server|
      # array returned
      result = server.call("snippet.list", $key)
    end
    if OPT[:target] == "mine"
      result = result.find_all { |e| not e["favorite"] }
    end
    result.map! do |e|
      flags = ""
      #flags << "P"  if  e["private"]
      flags << (e["favorite"] ? "F" : "M")

      "%6d [%s] %s" % [e["id"], flags, e["title"]]
    end
    return result
  end

  def langlist
    list = []
    Server.open_session($key) do |server|
      list = server.call("languages.list", $key)
    end
    list.values
  end

  def delete_cache(id)
    found = false
    @db.transaction do |db|
      found = true if db.root?(id)
    end

    if found
      db_delete(id)
    else
      puts "not found `#{id}'"
    end
  end

  # private methods
  private
  def db_read(id)
    @db.transaction do |db|
      return db[id]
    end
  end

  def db_update(snippet)
    id = snippet["id"]
    @db.transaction do |db|
      db[id] = snippet
    end
  end

  def db_delete(id)
    @db.transaction do |db|
      db.delete(id)
    end
  end
end

def vim_modeline(lang)
  result = ""
  lang.downcase!
  vim_ft = VIM_FT_LIST.keys.detect(lambda{ lang }){|k| VIM_FT_LIST[k].include?(lang ) }
  if ONELINE_COMMENT.has_key?(vim_ft)
    commentstr = ONELINE_COMMENT[vim_ft]
    if commentstr =~ /\{comment\}/
      result = commentstr.sub!(/\{comment\}/," vim: set ft=#{vim_ft}: ")
    else
      result = "#{commentstr} vim: set ft=#{vim_ft}: "
    end
  else
    result = "# vim: set ft=#{vim_ft}:"
  end
  return result
end

API_KEY_PATH = ENV['HOME'] + "/.snipplr/api_key"
DB_PATH = ENV['HOME'] + "/.snipplr/db.yml"

$key = File.read(API_KEY_PATH).chomp
snipplr = Snipplr.new

OPT = {
  :cmd => nil,
  :id => nil,
  :query => nil,
  :nocache => false,
  :lang => nil,
  :dump => nil,
  :target => "",
}
opts = OptionParser.new
opts.banner = "Usage: #{File.basename($0)} option arg"
opts.on( "-g", "--get query", String,  "get snippet for from  id or URL"){ |v| OPT[:cmd] = "get"; OPT[:query] = v }
opts.on( "-i", "--info id", String,  "display info for snippet"){ |v| OPT[:cmd] = "info"; OPT[:query] = v }
opts.on( "-d", "--delete id", String, "delete id's snippet from local cache"){ |v| OPT[:cmd] = "delete"; OPT[:id] = v }
opts.on( "-l", "--list","list entries."){ OPT[:cmd] = "list" }
opts.on( "--lang lang", String, "show only specified lang for list."){ |OPT[:lang]| }
opts.on( "-t", "--target [mine|all]","target for remote list[mine|all]."){ |OPT[:target]| }
opts.on( "--langlist","list supported language list"){ OPT[:cmd] = "langlist" }
opts.on( "--nocache", "don't use local cache"){ |OPT[:nocache]| }

begin
  opts.parse!
  snipplr = Snipplr.new
  case OPT[:cmd]
  when "get"
    e = snipplr.get(OPT[:query])
    if OPT[:dump]
      puts e["source"].to_yaml
    else
      puts e["source"]
    end
    puts vim_modeline(e["language"])
  when "info"
    e = snipplr.info(OPT[:query])
    puts e
  when "delete"
    snipplr.delete_cache(OPT[:id])
  when "list"
    puts snipplr.list
  #when "list_remote":
    #puts snipplr.list_remote
  when "langlist":
    puts snipplr.langlist
  else
    puts opts.help
  end
rescue OptionParser::ParseError => err
  $stderr.puts err.message
  $stderr.puts opts.help
  exit 1
end
__END__
["comment", "title", "snipplr_url", "language", "username", "tags", "id", "user_id", "source", "updated", "created"].each do |key|
