class StatementRecord < ApplicationRecord
  belongs_to :bank_statement

  validates :date, :amount, presence: true
end
