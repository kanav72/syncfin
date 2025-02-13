class BankStatementsController < ApplicationController
  before_action :authenticate_user!

  def new
    @bank_statement = BankStatement.new
  end

  def index
    @bank_statements = current_user.bank_statements
  end

  def create
    Rails.logger.debug "Received params: #{params.inspect}"  # Debugging line
    if params[:bank_statement].blank?
      Rails.logger.error "❌ bank_statement parameter is missing!"
    else
      Rails.logger.info "✅ bank_statement parameter exists: #{params[:bank_statement].inspect}"
    end

    @bank_statement = current_user.bank_statements.new(bank_statement_params)
    
    if @bank_statement.save
      Rails.logger.info "✅ File saved successfully: #{@bank_statement.file.filename}"
      redirect_to bank_statements_path, notice: "File uploaded successfully."
    else
      Rails.logger.error "❌ Failed to save file: #{@bank_statement.errors.full_messages.join(", ")}"
      render :new
    end
  end

  def destroy
    @bank_statement = BankStatement.find_by(id: params[:id])
    
    if @bank_statement
      @bank_statement.destroy
      redirect_to bank_statements_path, notice: "Bank statement deleted successfully."
    else
      redirect_to bank_statements_path, alert: "Bank statement not found."
    end
  end

  private

  def bank_statement_params
    params.require(:bank_statement).permit(:file)
  end
end