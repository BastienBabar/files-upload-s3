class CreateUploadedFiles < ActiveRecord::Migration[6.1]
  def change
    create_table :uploaded_files do |t|
      t.string :file_id
      t.timestamps
    end
  end
end
