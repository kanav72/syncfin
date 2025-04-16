class BankStatementsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_bank_statement, only: [:show, :edit, :update, :destroy]

  def new
    @bank_statement = BankStatement.new
  end

  def index
    @bank_statements = current_user.bank_statements
  end

  def show
  end

  def create
    return redirect_to(new_bank_statement_path, alert: "No file selected.") if params[:bank_statement].blank?

    @bank_statement = current_user.bank_statements.new(bank_statement_params)
    if @bank_statement.save
      if @bank_statement.process_file
        @bank_statement.save # Save metadata
        redirect_to bank_statements_path, notice: "File uploaded and processed successfully."
      else
        redirect_to bank_statements_path, alert: @bank_statement.errors.full_messages.join(", ")
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @bank_statement.update(bank_statement_params)
      redirect_to bank_statements_path, notice: "Bank statement updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @bank_statement.destroy
    redirect_to bank_statements_path, notice: "Bank statement deleted successfully."
  end

  private

  def set_bank_statement
    @bank_statement = current_user.bank_statements.find_by(id: params[:id])
    redirect_to bank_statements_path, alert: "Bank statement not found." unless @bank_statement
  end

  def bank_statement_params
    params.require(:bank_statement).permit(:file)
  end
end
