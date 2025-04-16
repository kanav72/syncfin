class BankStatement < ApplicationRecord
  belongs_to :user
  has_one_attached :file
  has_many :statement_records, dependent: :destroy

  validates :bank_name, :account_number, :period_start, :period_end, presence: true, on: :update
  validate :acceptable_file_type

  def process_file
    result = BankStatementParser.new(self).call
    unless result.success?
      errors.add(:file, result.error)
      return false
    end
    true
  end

  private

  def acceptable_file_type
    return unless file.attached?

    allowed_types = [
      "application/vnd.ms-excel",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      "application/pdf"
    ]

    unless allowed_types.include?(file.content_type)
      errors.add(:file, "must be an Excel file (.xls, .xlsx) or PDF (.pdf)")
    end
  end
end
