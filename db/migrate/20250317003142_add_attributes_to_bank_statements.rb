class AddAttributesToBankStatements < ActiveRecord::Migration[8.0]
  def change
    add_column :bank_statements, :bank_name, :string
    add_column :bank_statements, :account_number, :string
    add_column :bank_statements, :period_start, :date
    add_column :bank_statements, :period_end, :date
  end
end
