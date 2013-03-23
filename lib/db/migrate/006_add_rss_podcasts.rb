class AddRssPodcasts < ActiveRecord::Migration
  def self.up
    create_table :podcast_entries do |t|
      t.column :name, :string, :null => false
      t.column :summary, :text
      t.column :url, :string
      t.column :published_at, :string
      t.column :guid, :string
      t.column :source, :string
      t.column :imported, :int, :default => 0
    end
    create_table :podcast_feeds do |t|
      t.column :title, :string, :null => false
      t.column :link, :string
      t.column :id, :int
    end
  end
  
  def self.down
    drop_table :podcast_entries
    drop_table :podcast_feeds
  end
end