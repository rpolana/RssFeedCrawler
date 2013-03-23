class CreateRssEntries < ActiveRecord::Migration
  def self.up
    create_table :rss_entries do |t|
      t.column :name, :string, :null => false
      t.column :summary, :string
      t.column :url, :string
      t.column :published_at, :string
      t.column :guid, :string
      t.column :source, :string
    end
  end
  def self.down
    drop_table :rss_entries
  end
end