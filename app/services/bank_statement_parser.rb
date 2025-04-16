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

    unless valid_file_type?
      return Result.new(false, @bank_statement, "Invalid file type. Only Excel files (.xls, .xlsx) or PDFs (.pdf) are allowed.")
    end

    if excel_file?
      process_excel
    elsif pdf_file?
      process_pdf
    end
  rescue StandardError => e
    Result.new(false, @bank_statement, "Error processing file: #{e.message}")
  end

  private

  def valid_file_type?
    allowed_types = [
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/pdf"
    ]
    allowed_types.include?(@file.content_type)
  end

  def excel_file?
    @file.content_type.start_with?("application/vnd")
  end

  def pdf_file?
    @file.content_type == "application/pdf"
  end

  def process_excel
    Tempfile.open(["bank_statement", ".xlsx"], binmode: true) do |temp_file|
      temp_file.write(@file.download)
      temp_file.rewind

      return Result.new(false, @bank_statement, "Downloaded file is empty.") if temp_file.size.zero?

      xlsx = Roo::Spreadsheet.open(temp_file.path, extension: :xlsx)
      sheet = xlsx.sheet(0)

      extract_excel_metadata(sheet)
      extract_excel_statement_records(sheet)

      if @bank_statement.save
        Result.new(true, @bank_statement, nil)
      else
        Result.new(false, @bank_statement, @bank_statement.errors.full_messages.join(", "))
      end
    end
  end

  def process_pdf
    Tempfile.open(["bank_statement", ".pdf"], binmode: true) do |temp_file|
      temp_file.write(@file.download)
      temp_file.rewind

      return Result.new(false, @bank_statement, "Downloaded file is empty.") if temp_file.size.zero?

      reader = PDF::Reader.new(temp_file.path)
      return Result.new(false, @bank_statement, "PDF is empty or unreadable.") if reader.pages.empty?

      extract_pdf_metadata(reader)
      extract_pdf_statement_records(reader)

      if @bank_statement.valid?
        Result.new(true, @bank_statement, nil)
      else
        Result.new(false, @bank_statement, @bank_statement.errors.full_messages.join(", "))
      end
    end
  end

  def extract_excel_metadata(sheet)
    @bank_statement.bank_name = sheet.cell(1, 1) || "Unknown Bank"
    @bank_statement.account_number = sheet.cell(2, 1) || "Unknown"
    @bank_statement.period_start = Date.parse(sheet.cell(3, 1).to_s) if sheet.cell(3, 1)
    @bank_statement.period_end = Date.parse(sheet.cell(4, 1).to_s) if sheet.cell(4, 1)
  end

  def extract_excel_statement_records(sheet)
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

  def extract_pdf_metadata(reader)
    text = reader.pages.first.text
    lines = text.split("\n").map(&:strip).reject(&:empty?)

    @bank_statement.bank_name = lines.find { |l| l.match?(/Bank Name:/i) }&.sub(/Bank Name:\s*/i, "") || "Unknown Bank"
    @bank_statement.account_number = lines.find { |l| l.match?(/Account Number:/i) }&.sub(/Account Number:\s*/i, "") || "Unknown"

    period_line = lines.find { |l| l.match?(/Statement Period:/i) }
    if period_line
      dates = period_line.scan(/\d{4}-\d{2}-\d{2}/)
      @bank_statement.period_start = Date.parse(dates[0]) if dates[0]
      @bank_statement.period_end = Date.parse(dates[1]) if dates[1]
    end
  end

  def extract_pdf_statement_records(reader)
    text = reader.pages.map(&:text).join("\n")
    lines = text.split("\n").map(&:strip).reject(&:empty?)

    transaction_lines = lines.drop_while { |l| !l.match?(/Date\s+Description\s+Amount/i) }[1..-1] || []

    transaction_lines.each do |line|
      match = line.match(/^(\d{4}-\d{2}-\d{2})\s+(.+?)\s+(-?\d+\.\d{2})$/)
      next unless match

      date, description, amount = match.captures
      parsed_date = begin
        Date.parse(date)
      rescue ArgumentError
        nil
      end

      if parsed_date && amount.to_f != 0.0
        @bank_statement.statement_records.build(
          date: parsed_date,
          description: description,
          amount: amount.to_f
        )
      end
    end
  end
end
