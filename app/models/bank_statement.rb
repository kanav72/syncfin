class BankStatement < ApplicationRecord
  belongs_to :user
  has_one_attached :file
  has_many :statement_records, dependent: :destroy

  # Validate metadata after processing (on update, not create, since it’s extracted from the file)
  validates :bank_name, :account_number, :period_start, :period_end, presence: true, on: :update
  validate :acceptable_file_type

  # Process the uploaded Excel file
  def process_excel
    return unless file.attached?

    # Ensure it's a valid Excel file
    unless valid_excel_file?
      raise "Invalid file type. Only Excel files (.xls, .xlsx) are allowed."
    end

    # Temporarily open the file
    Tempfile.open(["bank_statement", ".xlsx"], binmode: true) do |temp_file|
      temp_file.write(file.download)
      temp_file.rewind

      if temp_file.size == 0
        raise "Downloaded file is empty!"
      end

      begin
        # Open the Excel file with Roo
        xlsx = Roo::Spreadsheet.open(temp_file.path, extension: :xlsx)
        sheet = xlsx.sheet(0)

        # Extract metadata (bank name, account number, period start, period end)
        extract_metadata(sheet)

        # Extract transaction rows and save as StatementRecords
        extract_statement_records(sheet)

        # Save the BankStatement with extracted data
        save!
      rescue => e
        errors.add(:file, "Error processing Excel file: #{e.message}")
        raise
      end
    end
  end

  private

  # Validate file type
  def acceptable_file_type
    return unless file.attached?

    allowed_types = [
      "application/vnd.ms-excel", # .xls
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" # .xlsx
    ]

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "must be an Excel file (.xls or .xlsx)")
    end
  end

  # Check if the file is a valid Excel file
  def valid_excel_file?
    acceptable_file_type
    errors.empty?
  end

  # Extract metadata from the Excel file (customize based on your file structure)
  def extract_metadata(sheet)
    # Assuming metadata is in specific cells
    self.bank_name = sheet.cell(1, 1) || "Unknown Bank" # Update this based on actual data cell locations
    self.account_number = sheet.cell(2, 1) || "Unknown" # Adjust based on actual location
    self.period_start = Date.parse(sheet.cell(3, 1).to_s) if sheet.cell(3, 1) # Adjust date formatting if necessary
    self.period_end = Date.parse(sheet.cell(4, 1).to_s) if sheet.cell(4, 1) # Adjust date formatting if necessary

    # Log the extracted metadata to verify it's working
    Rails.logger.debug("Extracted Metadata: Bank Name: #{self.bank_name}, Account Number: #{self.account_number}, Period Start: #{self.period_start}, Period End: #{self.period_end}")
  end

  # Extract transaction rows and create StatementRecord entries
  def extract_statement_records(sheet)
    # Assuming data starts at row 5 with columns: Date, Description, Amount
    sheet.each_row_streaming(offset: 4) do |row| # Skip header/metadata rows
      values = row.map(&:value)
      next if values.all?(&:blank?) # Skip empty rows

      # Parse date safely
      parsed_date = begin
        Date.parse(values[0].to_s)
      rescue ArgumentError, TypeError
        nil
      end

      # Only build records with valid date and amount
      if parsed_date && values[2].present?
        statement_records.build(
          date: parsed_date,          # Column A: Date
          description: values[1],     # Column B: Description
          amount: values[2].to_f      # Column C: Amount
        )
      end
    end
  end
end
