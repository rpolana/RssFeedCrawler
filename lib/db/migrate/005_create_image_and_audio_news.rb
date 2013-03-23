class CreateImageAndAudioNews < ActiveRecord::Migration
  def self.up
    create_table :image_entries do |t|
      t.column :url, :text, :null => false
      t.column :html, :text
      t.column :img, :string
      t.column :title, :string
      t.column :keywords, :string
      t.column :source, :string
      t.column :imported, :int, :default=>0
    end
    create_table :audio_entries do |t|
      t.column :url, :text, :null => false
      t.column :html, :text
      t.column :keywords, :string
      t.column :source, :string
      t.column :imported, :int, :default=>0
    end
  end
  
  def self.down
    drop_table :image_entries
    drop_table :audio_entries
  end
end