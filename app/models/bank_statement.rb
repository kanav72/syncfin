require 'roo'

# If you want to add more file types in the future, simply update the allowed_types array in the model and the accept attribute in the new.html.erb.
class BankStatement < ApplicationRecord
  belongs_to :user
  has_one_attached :file

  validate :acceptable_file_type
  
  def process_excel
    return unless file.attached?

    unless valid_excel_file?
      raise "Invalid file type. Only Excel files (.xls, .xlsx) are allowed."
    end

  
    Tempfile.open(["bank_statement", ".xlsx"], binmode: true) do |temp_file|
      temp_file.write(file.download)
      temp_file.rewind

      # Verify that the file is not empty
      if temp_file.size == 0
        raise "Downloaded file is empty!"
      end

      begin
        xlsx = Roo::Spreadsheet.open(temp_file.path, extension: :xlsx)

        xlsx.sheet(0).each_row_streaming do |row|
          puts row.map(&:value).join(", ")
        end
      rescue => e
        raise "Error processing Excel file: #{e.message}"
      end
    end
  end

  private

   def acceptable_file_type
    return unless file.attached?

    allowed_types = [
      "application/vnd.ms-excel", # .xls
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" # .xlsx
       # "application/pdf" # .pdf
    ]

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "must be an Excel file (.xls or .xlsx)")
    end
  end
end