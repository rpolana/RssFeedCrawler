
require 'rubygems'
require 'active_record'

class RssEntry < ActiveRecord::Base
  def self.add_entries_to_db_from_feed(feed, source)
    if not feed
      return 0
    end
    new_entry_count = 0
    feed.entries.each do |entry|
      begin
        #puts "  id=#{entry.id}:"
        #puts "    published_at=#{entry.published}"
        #puts "    title=#{entry.title}"
        #puts "    url=#{entry.url}"
        #puts "    summary=#{entry.summary}\n"
        unless exists? :guid => entry.id
          create!(
            :source => source,
            :name => entry.title,
            :summary => entry.summary,
            :url => entry.url,
            :published_at => entry.published,
            :guid => entry.id
          )
          new_entry_count += 1
        end
      rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while creating rss news entry #{entry.id}: " +
          e.message.to_s + ": " + e.inspect.to_s + ":  at <#{entry.url}>"
        # puts e.backtrace  
      end
    end
    return new_entry_count
  end
end

class PodcastEntry < ActiveRecord::Base
  def self.add_entries_to_db_from_feed(feed, source)
    if not feed
      return 0
    end
    new_entry_count = 0
    feed.entries.each do |entry|
      begin
        #puts "  id=#{entry.id}:"
        #puts "    published_at=#{entry.published}"
        #puts "    title=#{entry.title}"
        #puts "    url=#{entry.url}"
        #puts "    summary=#{entry.summary}\n"
        unless exists? :guid => entry.id
          create!(
            :source => source,
            :name => entry.title,
            :summary => entry.summary,
            :url => entry.url,
            :published_at => entry.published,
            :guid => entry.id
          )
          new_entry_count += 1
        end
      rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while creating podcast news entry #{entry.id}: " +
          e.message.to_s + ": " + e.inspect.to_s + ":  at <#{entry.url}>"
        # puts e.backtrace  
      end
    end
    return new_entry_count
  end
end

