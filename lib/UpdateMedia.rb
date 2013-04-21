require 'rubygems'
require 'active_record'
#require 'database_configuration'
require 'timeout'
require 'nokogiri'
require 'open-uri'
require 'uri'
require 'uuidtools'

MEDIA_UPDATE_PERIOD_IN_HOURS = 24
SEARCH_TIMEOUT_IN_SECONDS = 600
URL_OPEN_HEADERS_HASH = {"User-Agent" => "Ruby/#{RUBY_VERSION}"}


class Setting < ActiveRecord::Base
  @@CheckSettingsPeriodInSeconds = 5 
  @@MediaUpdatePeriodInHours = MEDIA_UPDATE_PERIOD_IN_HOURS
  @@RefreshNow = 0
  @@VideoNewsUrlBase = "rss_news/video_news"
  @@VideoNewsDirBase = "./rss_news/video_news"
  @@ImageNewsUrlBase = "rss_news/image_news"
  @@ImageNewsDirBase = "./rss_news/image_news"
  def self.update_settings()
    settings = self.find(:all)
    #puts "Updating settings from db: #{settings.size} settings (not all printed below)" 
    settings.each do |setting|
      if setting.name == "CheckSettingsPeriodInSeconds"
        @@CheckSettingsPeriodInSeconds = setting.value.to_i
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "MediaUpdatePeriodInHours"
        @@MediaUpdatePeriodInHours = setting.value.to_i
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "RefreshNow"
        @@RefreshNow = setting.value.to_i
      end
      if setting.name == "ExitNow"
        @@ExitNow = setting.value.to_i
      end
      if setting.name == "VideoNewsUrlBase"
        @@VideoNewsUrlBase = setting.value
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "ImageNewsUrlBase"
        @@ImageNewsUrlBase = setting.value
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "VideoNewsDirBase"
        if File.directory?(setting.value)
          @@VideoNewsDirBase = setting.value
        else
          puts "#{setting.name}: No such directory <#{setting.value}>"
        end
        #puts "#{setting.name}: #{setting.value}"
      end
      if setting.name == "ImageNewsDirBase"
        if File.directory?(setting.value)
          @@ImageNewsDirBase = setting.value
        else
          puts "#{setting.name}: No such directory <#{setting.value}>"
        end
        #puts "#{setting.name}: #{setting.value}"
      end
    end
    #puts "\n"
  end
  def self.CheckSettingsPeriod()
    return @@CheckSettingsPeriodInSeconds
  end
  def self.MediaUpdatePeriod()
    return @@MediaUpdatePeriodInHours
  end
  def self.RefreshNow()
    return @@RefreshNow
  end
  def self.ExitNow()
    return @@ExitNow
  end
  def self.VideoNewsUrlBase()
    return @@VideoNewsUrlBase
  end
  def self.ImageNewsUrlBase()
    return @@ImageNewsUrlBase
  end
  def self.VideoNewsDirBase()
    return @@VideoNewsDirBase
  end
  def self.ImageNewsDirBase()
    return @@ImageNewsDirBase
  end
end

class VideoEntry < ActiveRecord::Base
  @@google_search_prefix = "";
  @@yahoo_search_prefix = "";
  @@google_search_suffix = "";
  @@yahoo_search_suffix = "";
  def self.init() # VideoEntry
    init_google_search_prefix_suffix();
    init_yahoo_search_prefix_suffix();
  end
  def self.init_google_search_prefix_suffix() # VideoEntry
    @@google_search_prefix = "http://www.google.com/search?tbm=vid&q=%22"
    @@google_search_suffix = "%22" # surround the search keyword string with single quotes
    @@google_search_suffix += "&pws=0"
    @@google_search_suffix += "&num=100"
    case 
    when Setting.MediaUpdatePeriod < 24
      @@google_search_suffix += "&as_qdr=h"
    when Setting.MediaUpdatePeriod < 24*7
      @@google_search_suffix += "&as_qdr=d"
    when Setting.MediaUpdatePeriod < 24*30
      @@google_search_suffix += "&as_qdr=w"
    else
      @@google_search_suffix += "&as_qdr=m"
    end
    @@google_search_suffix += "&safe=active"
    @@google_video_play_prefix = "http://www.google.com"
  end
  def self.init_yahoo_search_prefix_suffix() # VideoEntry
    @@yahoo_search_prefix = "http://video.search.yahoo.com/search/video?p=%22"
    @@yahoo_search_suffix = "%22" # surround the search keyword string with single quotes
    @@yahoo_search_suffix += "&ei=utf-8&sort=new" # latest items first
    @@yahoo_video_play_prefix = "http://video.search.yahoo.com"
  end
  def self.get_search_url(keyword_string, search_source) # VideoEntry
    if search_source =~ /google/i
      keyword_string.strip!
      return @@google_search_prefix + URI::encode(keyword_string) + 
        @@google_search_suffix
    elsif search_source =~ /yahoo/i
      keyword_string.strip!
      return @@yahoo_search_prefix + URI::encode(keyword_string) + 
        @@yahoo_search_suffix
    else
      return nil
    end
  end  
  def self.get_url_from_search_item(item, source) # VideoEntry
    url = item.search('a').first['href']
    if url 
      url = URI::decode(url)
      puts "url=#{url}"
      # get rid of yahoo additions to url
      if (source =~ /yahoo/i)
        position = (url =~ /\&sort/i)
        if (position)
          url = url[0..(position-1)]
        end
        position = (url =~ /\&back/i)
        if (position)
          url = url[0..(position-1)]
        end
        position = (url =~ /\&rurl=/i)
        if (position)
          url = url[(position+6)..(-1)]
        end
      end
      if (url =~ /^\/video\/play/)
        if(source =~ /google/i)
          url = @@google_video_play_prefix + url
        elsif (source =~ /yahoo/i)
          url = @@yahoo_video_play_prefix + url
        else
          puts "get_url_from_search_item: unknown source #{source} for item: #{item}"
          return nil
        end
      else
        position = (url =~ /http\:\/\//i)
        if(position)
          url = url[position..-1]

          # get rid of any referrer, check if there is another url inside and get that
          position = (url[7..-1] =~ /http\:\/\//i)
          if(position)
            url = url[(position+7)..-1]
          end
        end
      end
    end
    return url
  end
  
  def self.add_entry(item, keyword_string, source) # VideoEntry
    # get the url and html for each item 
    url = get_url_from_search_item(item, source)
    if not url 
      return 0
    end
    html = item.inner_html
    # take off bolding keywords
    html.gsub!("<b>"+keyword_string+"</b>", keyword_string)
    html.gsub!("<b " + keyword_string + ">", keyword_string)
    # extract other properties from item
    image_src = nil
    title = nil
    description = nil
    duration = nil
    when_string = nil
    if (source =~ /yahoo/i) 
      img = item.search("img/@src").first
      if(img)
        image_src = img.value
        #tmpfilename = Dir::Tmpname.make_tmpname("image_", nil)
        tmpfilename = UUIDTools::UUID.timestamp_create
        tmpfilenamefull = Setting.VideoNewsDirBase + "/image_" + tmpfilename 
        #uri = URI.parse(url).merge(URI.parse(image_src)).to_s
        uri = URI.parse(image_src).to_s
        File.open(tmpfilenamefull,'wb'){ |f| 
          f.write(open(uri).read) 
          image_src = Setting.VideoNewsUrlBase+"/image_"+tmpfilename
          puts "changed image link to #{image_src}"
        }
      end
      position = (url =~ /\&tit\=/i)
      if (position)
        title_to_end = url[(position+5)..-1]
        position2 = (title_to_end =~ /\&/i)
        if position2 
          title = title_to_end[0..(position2-1)]
          title.gsub!("+", " ")
        end
      end
      duration_element = item.search("span[@class='note dur']").first
      if duration_element 
        duration = duration_element.text
      end
      span_elements = item.search("span");
      when_element = nil;
      while (span_element = span_elements.pop())
        if span_element['class'] =~ /age/
          when_element = span_element;
          break;
        end
      end
      if when_element 
        when_string = when_element.text
        if (when_string =~ /ago/i)
          yet_to_parse_ago = true
          position = (when_string =~ /\hours\=/i)
          if(position and yet_to_parse_ago)
            hours = when_string[0..(position-1)]
            if(hours.match(/^\d+$/))
              hours = hours.to_i
              when_string = (Time.now - (hours*60.0*60)).to_s
              yet_to_parse_ago = false
            end
          end
          position = (when_string =~ /\days\=/i)
          if(position and yet_to_parse_ago)
            days = when_string[0..(position-1)]
            if(days.match(/^\d+$/))
              days = days.to_i
              when_string = (Date.today - days).to_s
              yet_to_parse_ago = false
            end
          end
          position = (when_string =~ /\months\=/i)
          if(position and yet_to_parse_ago)
            months = when_string[0..(position-1)]
            if(months.match(/^\d+$/))
              months = months.to_i
              when_string = (Date.today - months*30.0).to_s
              yet_to_parse_ago = false
            end
          end
          if(yet_to_parse_ago)
            when_string = Date.today.to_s
          end
        end
      end
      data = item.search('a').first['data'] # description is inside data
      if(data)
        position = (data =~ /\"d\":\"/)
        if position
          d_to_end = data[(position+5)..-1]
          position2 = (d_to_end =~ /\"\}/)
          if position2
            description = d_to_end[0..(position2-1)]
            description = URI::decode(description)
          end
        end
      end
    end
    
    puts "url=#{url}: creating entry"
    unless exists? :url => url
      create!(
        :url => url,
        :source => source,
        :keywords => keyword_string, 
        :html => html,
        :description => description,
        :title => title,
        :duration => duration,
        :when => when_string,
        :img => image_src
      )
      return 1
    end        
    return 0
  end
  def self.search(keywords_entry)
    count = 0
    new_entry_count = 0
    keyword_string = keywords_entry.keywords
    video_search_url = VideoEntry.get_search_url(keyword_string, keywords_entry.source)
    if video_search_url 
      puts "video search_url = #{video_search_url}"
      doc = Nokogiri::HTML(File.read(open(video_search_url, URL_OPEN_HEADERS_HASH).path))
      if keywords_entry.source =~ /google/i
        li = doc.search('li')
        puts "**BEGIN video element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /vid/i)
            count += 1
            puts "class=<" + litem['class'] + ">: #{count}:" + "#{litem.search('table').first}"
            added_count = VideoEntry.add_entry(litem.search('table').first, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          else
            # ignore non-video list items
          end
        end
        puts "**END video element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      elsif keywords_entry.source =~ /yahoo/i
        li = doc.search('li')
        puts "**BEGIN video element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /vr/i)
            count += 1
            puts "Yahoo search source: #{count}:" + "#{litem}"
            added_count = VideoEntry.add_entry(litem, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          else
            # ignore non-video list items
          end
        end
        puts "**END video element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      else
        # nothing to do
        puts "**WARNING: unknown search source: #{keyword_entry.source}, doc: #{doc}"
      end
    end # if (video_search_url)
    return [count, new_entry_count]
  end # def self.search
end # VideoEntry


class ImageEntry < ActiveRecord::Base
  @@google_search_prefix = "";
  @@yahoo_search_prefix = "";
  @@google_search_suffix = "";
  @@yahoo_search_suffix = "";
  def self.init()
    init_google_search_prefix_suffix();
    init_yahoo_search_prefix_suffix();
  end
  def self.init_google_search_prefix_suffix()
    @@google_search_prefix = "http://images.google.com/images&q=%22"
    @@google_search_suffix = "%22" # surround the search keyword string with single quotes
    @@google_search_suffix += "&pws=0"
    @@google_search_suffix += "&num=100"
    case 
    when Setting.MediaUpdatePeriod < 24
      @@google_search_suffix += "&as_qdr=h"
    when Setting.MediaUpdatePeriod < 24*7
      @@google_search_suffix += "&as_qdr=d"
    when Setting.MediaUpdatePeriod < 24*30
      @@google_search_suffix += "&as_qdr=w"
    else
      @@google_search_suffix += "&as_qdr=m"
    end
    @@google_search_suffix += "&safe=active"
  end
  def self.init_yahoo_search_prefix_suffix()
    @@yahoo_search_prefix = "http://images.search.yahoo.com/search/images?p=%22"
    @@yahoo_search_suffix = "%22" # surround the search keyword string with single quotes
    @@yahoo_search_suffix += "&ei=utf-8&sort=new" # latest items first
  end
  def self.get_search_url(keyword_string, search_source)
    if search_source =~ /google/i
      keyword_string.strip!
      return @@google_search_prefix + URI::encode(keyword_string) + 
        @@google_search_suffix
    elsif search_source =~ /yahoo/i
      keyword_string.strip!
      return @@yahoo_search_prefix + URI::encode(keyword_string) + 
        @@yahoo_search_suffix
    else
      return nil
    end
  end  
  def self.add_entry(item, keyword_string, source)
    # get the url and html for each item 
    url = VideoEntry.get_url_from_search_item(item, source)
    if not url 
      return 0
    end
    title= nil
    image_src = nil
    if (source =~ /yahoo/i) 
      img = item.search("img/@src").first
      if(img)
        image_src = img.value
        #tmpfilename = Dir::Tmpname.make_tmpname("image_", nil)
        tmpfilename = UUIDTools::UUID.timestamp_create
        tmpfilenamefull = Setting.ImageNewsDirBase + "/image_" + tmpfilename 
        #uri = URI.parse(url).merge(URI.parse(image_src)).to_s
        uri = URI.parse(image_src).to_s
        File.open(tmpfilenamefull,'wb'){ |f| 
          f.write(open(uri).read) 
          image_src = Setting.ImageNewsUrlBase+"/image_"+tmpfilename
          puts "changed image link to #{image_src}"
        }
      end
      # get title from the name attribute in url
      position = (url =~ /\&name\=/i)
      if (position)
        title_to_end = url[(position+6)..-1]
        url = url[0..(position-1)]
        position2 = (title_to_end =~ /\&/i)
        if position2 
          title = title_to_end[0..(position2-1)]
          title.gsub!("+", " ")
        end
      end
      # remove size attribute if it exists
      position = (url =~ /\&size\=/i)
      if (position)
        url = url[0..(position-1)]
      end
    end
    puts "url=#{url}: creating entry"
    unless exists? :url => url
      create!(
        :url => url,
        :source => source,
        :keywords => keyword_string, 
        :html => item.inner_html,
        :img => image_src,
        :title => title
      )
      return 1
    end        
    return 0
  end
  def self.search(keywords_entry)
    count = 0
    new_entry_count = 0
    keyword_string = keywords_entry.keywords
    image_search_url = ImageEntry.get_search_url(keyword_string, keywords_entry.source)
    if image_search_url 
      puts "image search_url = #{image_search_url}"
      doc = Nokogiri::HTML(File.read(open(image_search_url, URL_OPEN_HEADERS_HASH).path))
      if keywords_entry.source =~ /google/i
        li = doc.search('li')
        puts "**BEGIN image element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /im/i)
            count += 1
            puts "class=<" + litem['class'] + ">: #{count}:" + "#{litem.search('table').first}"
            added_count = ImageEntry.add_entry(litem.search('table').first, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          else
            # ignore non-image list items
          end
        end
        puts "**END image element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      elsif keywords_entry.source =~ /yahoo/i
        li = doc.search('li')
        puts "**BEGIN image element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /ld/i)
            count += 1
            puts "Yahoo search source: #{count}:" + "#{litem}"
            added_count = ImageEntry.add_entry(litem, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          end
        end
        puts "**END image element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      else
        # nothing to do
        puts "**WARNING: unknown search source: #{keyword_entry.source}, doc: #{doc}"
      end
    end # if (image_search_url)
    return [count, new_entry_count]
  end # def self.search
end

class AudioEntry < ActiveRecord::Base
  @@google_search_prefix = "";
  @@yahoo_search_prefix = "";
  @@google_search_suffix = "";
  @@yahoo_search_suffix = "";
  def self.init()
    init_google_search_prefix_suffix();
    init_yahoo_search_prefix_suffix();
  end
  def self.init_google_search_prefix_suffix()
    @@google_search_prefix = "http://www.google.com/search?tbm=vid&q=%22"
    @@google_search_suffix = "%22" # surround the search keyword string with single quotes
    @@google_search_suffix += "&pws=0"
    @@google_search_suffix += "&num=100"
    case 
    when Setting.MediaUpdatePeriod < 24
      @@google_search_suffix += "&as_qdr=h"
    when Setting.MediaUpdatePeriod < 24*7
      @@google_search_suffix += "&as_qdr=d"
    when Setting.MediaUpdatePeriod < 24*30
      @@google_search_suffix += "&as_qdr=w"
    else
      @@google_search_suffix += "&as_qdr=m"
    end
    @@google_search_suffix += "&safe=active"
  end
  def self.init_yahoo_search_prefix_suffix()
    @@yahoo_search_prefix = "http://video.search.yahoo.com/search/video?p=%22"
    @@yahoo_search_suffix = "%22" # surround the search keyword string with single quotes
    @@yahoo_search_suffix += "&ei=utf-8&sort=new" # latest items first
  end
  def self.get_search_url(keyword_string, search_source)
    if search_source =~ /google/i
      keyword_string.strip!
      return @@google_search_prefix + URI::encode(keyword_string) + 
        @@google_search_suffix
    elsif search_source =~ /yahoo/i
      keyword_string.strip!
      return @@yahoo_search_prefix + URI::encode(keyword_string) + 
        @@yahoo_search_suffix
    else
      return nil
    end
  end  
  def self.add_entry(item, keyword_string, source)
      # get the url and html for each item 
      url = VideoEntry.get_url_from_search_item(item, source)
      if not url 
        return 0
      end
      puts "url=#{url}: creating entry"
      unless exists? :url => url
        create!(
          :url => url,
          :source => source,
          :keywords => keyword_string, 
          :html => item.inner_html
        )
        return 1
      end        
      return 0
  end
  def self.search(keywords_entry)
    count = 0
    new_entry_count = 0
    keyword_string = keywords_entry.keywords
    audio_search_url = AudioEntry.get_search_url(keyword_string, keywords_entry.source)
    if audio_search_url 
      puts "audio search_url = #{audio_search_url}"
      doc = Nokogiri::HTML(File.read(open(audio_search_url, URL_OPEN_HEADERS_HASH).path))
      if keywords_entry.source =~ /google/i
        li = doc.search('li')
        puts "**BEGIN audio element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /im/i)
            count += 1
            puts "class=<" + litem['class'] + ">: #{count}:" + "#{litem.search('table').first}"
            added_count = ImageEntry.add_entry(litem.search('table').first, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          else
            # ignore non-audio list items
          end
        end
        puts "**END audio element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      elsif keywords_entry.source =~ /yahoo/i
        li = doc.search('li')
        puts "**BEGIN audio element list: for keywords <#{keyword_string}>"
        li.each do |litem|
          if (litem['class'] =~ /im/i)
            count += 1
            puts "Yahoo search source: #{count}:" + "#{litem}"
            added_count = AudioEntry.add_entry(litem, 
              keyword_string, keywords_entry.source)
            new_entry_count += added_count
          else
            # ignore non-audio list items
          end
        end
        puts "**END audio element list: for keywords <#{keyword_string}>: total video entries: #{count}, new db entries: #{new_entry_count}"
      else
        # nothing to do
        puts "**WARNING: unknown search source: #{keyword_entry.source}, doc: #{doc}"
      end
    end # if (audio_search_url)
    return [count, new_entry_count]
  end # def self.search
end


class SearchKeyword < ActiveRecord::Base
end

class UpdateMediaNews
  def self.init(db_config_file)
    ActiveRecord::Base.establish_connection(YAML::load(File.open(db_config_file)))
    VideoEntry.init()
    ImageEntry.init()
    AudioEntry.init()
  end
  def self.update()
    Setting.update_settings()
    search_keywords = SearchKeyword.find(:all)
    video_new_entry_count = 0
    video_count = 0
    image_new_entry_count = 0
    image_count = 0
    audio_new_entry_count = 0
    audio_count = 0
    puts "***BEGIN search: #{search_keywords.size} keywords: #{DateTime.now.to_s}"
    search_keywords.each do |keywords_entry|
      keyword_string = keywords_entry.keywords
      puts "**Updating video news entries for keyword_string = #{keyword_string}"
      return_values = Array.new
      begin
        Timeout::timeout(SEARCH_TIMEOUT_IN_SECONDS) do
          return_values = VideoEntry.search(keywords_entry)
          video_count += return_values[0]
          video_new_entry_count += return_values[1]
        end
      rescue Timeout::Error => te
        puts DateTime.now.to_s + ": Video search timedout:(#{keywords_entry.source}:#{keyword_string}) after #{SEARCH_TIMEOUT_IN_SECONDS}seconds: #{te}"
      rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while doing video search:(#{keywords_entry.source}:#{keyword_string}): " +
          e.message.to_s + ": " + e.inspect.to_s
        puts e.backtrace  
      end

      puts "**Updating image news entries for keyword_string = #{keyword_string}"
      begin
        Timeout::timeout(SEARCH_TIMEOUT_IN_SECONDS) do
          return_values = ImageEntry.search(keywords_entry)
          image_count += return_values[0]
          image_new_entry_count += return_values[1]
        end
      rescue Timeout::Error => te
        puts DateTime.now.to_s + ": Image search timedout:(#{keywords_entry.source}:#{keyword_string}) after #{SEARCH_TIMEOUT_IN_SECONDS}seconds: #{te}"
      rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while doing image search:(#{keywords_entry.source}:#{keyword_string}): " +
          e.message.to_s + ": " + e.inspect.to_s
        puts e.backtrace  
      end
      #puts "**Updating audio news entries for keyword_string = #{keyword_string}"
      begin
        Timeout::timeout(SEARCH_TIMEOUT_IN_SECONDS) do
          #return_values = AudioEntry.search(keywords_entry)
          #audio_count += return_values[0]
          #audio_new_entry_count += return_values[1]
        end
      rescue Timeout::Error => te
        puts DateTime.now.to_s + ": Audio search timedout:(#{keywords_entry.source}:#{keyword_string}) after #{SEARCH_TIMEOUT_IN_SECONDS}seconds: #{te}"
      rescue Exception => e
        puts DateTime.now.to_s + ": **** Exception while doing audio search:(#{keywords_entry.source}:#{keyword_string}): " +
          e.message.to_s + ": " + e.inspect.to_s
        puts e.backtrace  
      end
    end # search_keywords.each
    puts "***END search: #{search_keywords.size} keywords: "
    puts "  total video entries: #{video_count}, new db video entries: #{video_new_entry_count}"
    puts "  total image entries: #{image_count}, new db image entries: #{image_new_entry_count}"
    #puts "  total audio entries: #{audio_count}, new db audio entries: #{audio_new_entry_count}"
  end # def update
end #class UpdateMediaNews


#if ARGV[0]
#  rss_images_basename = ARGV[0]
#end

UpdateMediaNews.init('db/config/database.yml')
UpdateMediaNews.update()
