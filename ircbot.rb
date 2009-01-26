require 'socket'
require 'set'

class IrcBot

  CODES = {"376" => :RPL_ENDOFMOTD,
           "353" => :RPL_NAMREPLY}

  @@handlers = []

  def users; @@users end
  def users= value; @@users = value end

  # FIXME we should stop abusing class variables
  def self.users; @@users end
  def self.users= value; @@users = value end

  def initialize args
    @args = args
    args[:port] = 6667 unless args.key? :port
    args[:desc] = "bot" unless args.key? :desc
    raise ArgumentError unless [:server,:nick,:chan,:pass].all? {|k| args[k]}

    self.users = Set.new
  end

  # Main loop
  def run
    begin
      @sock = TCPSocket::new(@args[:server], @args[:port])
      write :NICK,@args[:nick]
      write :USER,(@args[:nick]+" 0 * :bot")
      @sock.each_line do |line|
        puts "< #{line}"
        handle line
      end
    rescue Interrupt # ^C
      puts
    ensure
      @sock.close unless @sock.nil?
    end
  end

  def RPL_NAMREPLY line
    _,list = line.split ':',2
    list.split.each {|word| add_user word}
  end

  def handle_JOIN line
    add_user (parse_user line)
  end

  def handle_LEAVE line
    del_user (parse_user line)
  end

  def parse_user line
    return line.sub(/^:/,'').split('!')[0]
  end

  def add_user user
    user.sub! /^[@+]/,''
    users << user
  end

  def del_user user
    users.delete user
  end

  def RPL_ENDOFMOTD line
    write :JOIN, @args[:chan]
  end

  # Sends an IRC command to the server and also to stdout
  def write cmd,arg
    cmd = cmd.to_s.upcase
    @sock.puts "%s %s\r\n" % [cmd,arg]
    puts "> %s %s\n" % [cmd,arg]
  end

  def say it
    case it
    when /^\/me (.*)/
      write :PRIVMSG, "#{@args[:chan]} :\1ACTION #{$1}\1"
    else
      write :PRIVMSG, "#{@args[:chan]} :#{it}"
    end
  end

  # Called for every line received
  def handle line
    x1,x2,x3,x4 = line.split ' ', 4
    x1.sub! /^:/,''
    x4.sub! /^:/,'' if x4
    x4.chomp! if x4
    code = CODES[x2]
    if "PING" == x1
      write :PONG, x2
    elsif /^NickServ/ === x1
      if /nickserv identify/i === x4
        write :PRIVMSG, "NickServ :identify #{@args[:pass]}"
      elsif /password accepted/i === x4
        write :JOIN, @args[:chan]
      end
    elsif "JOIN" == x2
      handle_JOIN x1
    elsif %w(PART QUIT).include? x2
      handle_LEAVE x1
    elsif code and respond_to? code
      send code,x4
    elsif "PRIVMSG" == x2 and @args[:chan] == x3
      dispatch (parse_user x1),x4
    end
  end

  # We've received a message from someone
  # Time to figure out if it's a bot command
  def dispatch from,msg
    cmd,args = msg.split ' ',2
    @@handlers.each do |pattern,prc|
      if pattern === cmd
        # Figure out what arguments the callback would like
        # and if we have enough or too many arguments
        nargs = if prc.arity < 0 then ~prc.arity else prc.arity end
        case nargs
        when 0
          result = prc.call unless args
        else
          args.split ' ',nargs
          result = prc.call(*args)
        end
        say result
      end
    end
  end

  # Declares a bot command
  # pattern => string or regex to match the command
  def self.cmd pattern,&b
    @@handlers << [pattern,b]
  end
end
