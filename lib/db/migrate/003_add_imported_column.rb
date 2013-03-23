class AddImportedColumn < ActiveRecord::Migration
  def self.up
    add_column :rss_entries, :imported, :int, :default=>0
  end
  def self.down
    remove_column :rss_entries, :imported
  end
end