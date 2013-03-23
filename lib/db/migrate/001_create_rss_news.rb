class CreateRssNews < ActiveRecord::Migration
  def self.up
    create_table :rss_entries do |t|
      t.column :name, :string, :null => false
      t.column :summary, :string
      t.column :url, :string
      t.column :published_at, :string
      t.column :guid, :string
      t.column :source, :string
    end
    create_table :rss_feeds do |t|
      t.column :title, :string, :null => false
      t.column :link, :string
      t.column :id, :int
    end
    create_table :settings do |t|
      t.column :name, :string, :null => false
      t.column :value, :string
      t.column :id, :int 
    end
  end
  def self.down
    drop_table :rss_entries
	drop_table :rss_feeds
	drop_table :settings
  end
end