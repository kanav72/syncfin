class BankStatementParser
  Result = Struct.new(:success?, :bank_statement, :error)

  def initialize(bank_statement)
    @bank_statement = bank_statement
    @file = bank_statement.file
  end

  def call
    unless @file.attached?
      return Result.new(false, @bank_statement, "No file attached.")
    end

    unless valid_excel_file?
      return Result.new(false, @bank_statement, "Invalid file type. Only Excel files (.xls, .xlsx) are allowed.")
    end

    Tempfile.open(["bank_statement", ".xlsx"], binmode: true) do |temp_file|
      temp_file.write(@file.download)
      temp_file.rewind

      return Result.new(false, @bank_statement, "Downloaded file is empty.") if temp_file.size.zero?

      xlsx = Roo::Spreadsheet.open(temp_file.path, extension: :xlsx)
      sheet = xlsx.sheet(0)

      extract_metadata(sheet)
      extract_statement_records(sheet)

      if @bank_statement.save
        Result.new(true, @bank_statement, nil)
      else
        Result.new(false, @bank_statement, @bank_statement.errors.full_messages.join(", "))
      end
    end
  rescue StandardError => e
    Result.new(false, @bank_statement, "Error processing Excel file: #{e.message}")
  end

  private

  def valid_excel_file?
    allowed_types = [
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ]
    allowed_types.include?(@file.content_type)
  end

  def extract_metadata(sheet)
    @bank_statement.bank_name = sheet.cell(1, 1) || "Unknown Bank"
    @bank_statement.account_number = sheet.cell(2, 1) || "Unknown"
    @bank_statement.period_start = Date.parse(sheet.cell(3, 1).to_s) if sheet.cell(3, 1)
    @bank_statement.period_end = Date.parse(sheet.cell(4, 1).to_s) if sheet.cell(4, 1)
  end

  def extract_statement_records(sheet)
    sheet.each_row_streaming(offset: 4) do |row|
      values = row.map(&:value)
      next if values.all?(&:blank?)

      parsed_date = begin
        Date.parse(values[0].to_s)
      rescue ArgumentError, TypeError
        nil
      end

      if parsed_date && values[2].present?
        @bank_statement.statement_records.build(
          date: parsed_date,
          description: values[1],
          amount: values[2].to_f
        )
      end
    end
  end
end