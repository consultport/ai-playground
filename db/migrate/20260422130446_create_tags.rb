class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :tags, "LOWER(name)", unique: true, name: "index_tags_on_lower_name"
  end
end
