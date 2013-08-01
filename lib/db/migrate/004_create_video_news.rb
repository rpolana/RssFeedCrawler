class VideoEntry < ActiveRecord::Base
end


class CreateVideoNews < ActiveRecord::Migration
  def self.up
    if not VideoEntry.table_exists? 
      create_table  :video_entries do |t|
        t.column :url, :text, :null => false
        t.column :title, :string
        t.column :description, :text
        t.column :img, :string
        t.column :when, :string
        t.column :duration, :string
        t.column :html, :text
        t.column :keywords, :string
        t.column :source, :string
        t.column :imported, :int, :default=>0
      end
    end
    if not ActiveRecord::Base.connection.table_exists?('search_keywords')
      create_table :search_keywords do |t|
        t.column :keywords, :string, :null => false
        t.column :source, :string
        t.column :imported, :int, :default=>0
        t.column :last_updated, :datetime
      end
    end
  end
  
  def self.down
    drop_table :video_entries
    drop_table :search_keywords
  end
end