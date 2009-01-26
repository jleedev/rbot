#!/usr/bin/env ruby

require 'ircbot'

class Bot < IrcBot

  cmd "!fortune" do ||
    `fortune -s`.chomp.gsub /[\n\t ]+/,' '
  end

  cmd "!slap" do |who|
    if users.member? who
      "/me slaps #{who} with a trout"
    end
  end

end

bot = Bot::new :server => "irc.cwru.edu", :nick => "GohonaBot",
               :pass => "suprfsat", :chan => "#tutbot-testing",
               :desc => "Ruby IRC bot"
bot.run
