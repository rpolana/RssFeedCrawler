class ChangeSummaryToText < ActiveRecord::Migration
  def self.up
    change_column :rss_entries, :summary, :text 
  end
  def self.down
    change_column :rss_entries, :summary, :string 
  end
end