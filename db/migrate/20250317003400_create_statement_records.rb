class CreateStatementRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :statement_records do |t|
      t.references :bank_statement, null: false, foreign_key: true
      t.date :date
      t.string :description
      t.decimal :amount, precision: 15, scale: 2

      t.timestamps
    end
  end
end
