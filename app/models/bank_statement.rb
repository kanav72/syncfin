require 'roo'

class BankStatement < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  def process_excel
    return unless file.attached?

    # Create a Tempfile and ensure it is fully written
    Tempfile.open(["bank_statement", ".xlsx"]) do |temp_file|
      temp_file.binmode
      temp_file.write(file.download) # Write file content
      temp_file.rewind # Ensure file is fully written

      # Verify that the file is not empty
      if temp_file.size == 0
        raise "Downloaded file is empty!"
      end

      # Read the file using Roo
      xlsx = Roo::Spreadsheet.open(temp_file.path, extension: :xlsx)

      xlsx.sheet(0).each_row_streaming do |row|
        puts row.map(&:value) # Replace with actual processing logic
      end
    end
  end
end
