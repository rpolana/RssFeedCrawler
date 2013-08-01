require 'rubygems'
require 'feedzirra'
require 'active_record'
#require 'database_configuration'
require 'timeout'
require 'optparse'

FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS = 240

commandline_options = {}
commandline_options[:feed_type] = 'news'
OptionParser.new do |options|
  options.banner = "Usage: #{$0} [options]"
  # link is mandatory argument to a -f option (optional arguments would be like: --feed_url [link])
  options.on("-f", "--feed_urls_file filename", 
      "Name of file containing rss feed url links one on each line followed by source name") do |filename|
#    commandline_options[:feed_urls_file] = filename
  end
  options.on("-l", "--feed_urls link1, link2, link2", Array, 
      "list of rss feed url links") do |links|
    commandline_options[:feed_urls] = links
  end
end.parse!

p commandline_options
p ARGV
if commandline_options[:feed_urls_file] 
  rss_feeds = Hash.new
  feeds_file = File.open(commandline_options[:feed_urls_file], "r");
  if feeds_file
    puts "Reading rss feeds from " + commandline_options[:feed_urls_file]
    new_entry_count = 0
    feeds_file.each_line do | line |
      if (line[0] == '#') or (line.length <= 1)
        next # ignore comments and empty lines
      end
      line_fields = line.split(" ")
      if (line_fields.size >=2)
        link = line_fields[0]
        link_length = link.size
        unless (link_length == 0) or (rss_feeds.has_key? link)
          title = line[(link_length+1)..-2]
          rss_feeds[link]=title
          new_entry_count += 1
          puts "Added feed #{new_entry_count}: link <#{link}> with title <#{title}>"
        end
      end
    end
    puts "Added #{new_entry_count} feeds total"
  else
    puts "Could not read feeds file #{commandline_options[:feed_urls_file]}"
    exit 0
  end
elsif commandline_options[:feed_urls] 
  rss_feeds = commandline_options[:feed_url]
else
  source = 'Test'
  rss_feeds = {
    'http://www.whro.org/home/html/podcasts/discoverynow/podcast.xml'=>'NPR Discovery Now Podcast by WHRV',
    'http://podcastfeeds.nbcnews.com/audio/podcast/MSNBC-NN-NETCAST-M4V.xml' => source, # worked as of 10May2013
    'http://podacademy.org/feed/podcast/'  => source # worked as of 10May2013
  }
end

total_new_entry_count = 0

rss_feeds.each do |rss_feed_url, source|
  puts DateTime.now.to_s + ": Fetching rss entries from #{source}:<#{rss_feed_url}>:"
  new_entry_count = 0
  feed = nil
  begin
    Timeout::timeout(FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS) do
      feed = Feedzirra::Feed.fetch_and_parse(rss_feed_url)
    end
  rescue Timeout::Error => te
    puts DateTime.now.to_s + ": Feed fetch_and_parse timedout:(#{rss_feed_url}) after #{FEED_FETCH_AND_PARSE_TIMEOUT_IN_SECONDS}seconds: #{te}"
  rescue Exception => e
    puts DateTime.now.to_s + ": **** Exception while fetch_and_parse feed at <#{rss_feed_url}>: " +
      e.message.to_s + ": " + e.inspect.to_s
    puts e.backtrace  
  end
  if (feed.is_a?(Feedzirra::Parser::RSS) and (feed.entries.count > 0))
    new_entry_count = feed.entries.count
    puts "  Got rss entries from <#{rss_feed_url}>: total #{feed.entries.count}: new #{new_entry_count}"
  elsif feed.is_a?(Feedzirra::Parser::RSS)
    puts "  Feedzirra::Feed.fetch_and_parse feed <#{rss_feed_url}> returned 0 entries"
  else
    puts "  Feedzirra::Feed.fetch_and_parse feed <#{rss_feed_url}> returned <#{feed}>"
  end

  puts "\n#{DateTime.now}: ********** " + new_entry_count.to_s + " new news entries "
  total_new_entry_count += new_entry_count
end
puts "\n#{DateTime.now}: **********Total " + total_new_entry_count.to_s + " new news entries "
