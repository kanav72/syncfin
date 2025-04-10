class BankStatementsController < ApplicationController
  before_action :authenticate_user!

  def new
    @bank_statement = BankStatement.new
  end

  def index
    @bank_statements = current_user.bank_statements if user_signed_in?
  end

  def show
    @bank_statement = BankStatement.find(params[:id])
    # redirect_to rails_blob_path(@bank_statement.file, disposition: "attachment")
  end

  def create
    Rails.logger.debug "Received params: #{params.inspect}"  # Debugging line

    if params[:bank_statement].blank?
      Rails.logger.error "❌ bank_statement parameter is missing!"
      redirect_to new_bank_statement_path, alert: "No file selected."
      return
    end

    @bank_statement = current_user.bank_statements.new(bank_statement_params)

    if @bank_statement.save
      Rails.logger.info "✅ File saved successfully: #{@bank_statement.file.filename}"

      begin
        @bank_statement.process_excel
        Rails.logger.info "✅ Excel file processed successfully."
      rescue => e
        Rails.logger.error "❌ Error processing Excel file: #{e.message}"
        flash[:alert] = "File uploaded successfully, but there was an error processing it: #{e.message}"
      end

      redirect_to bank_statements_path, notice: "File uploaded successfully."
    else
      Rails.logger.error "❌ Failed to save file: #{@bank_statement.errors.full_messages.join(", ")}"
      render :new, status: :unprocessable_entity, alert: @bank_statement.errors.full_messages.join(", ")
    end
  end

  def edit
    @bank_statement = current_user.bank_statements.find(params[:id])
  end

  def update
    @bank_statement = current_user.bank_statements.find(params[:id])

    if @bank_statement.update(bank_statement_params)
      redirect_to bank_statements_path, notice: "Bank statement updated successfully."
    else
      render :edit, alert: @bank_statement.errors.full_messages.join(", ")
    end
  end

  def destroy
    @bank_statement = current_user.bank_statements.find(params[:id])
    Rails.logger.info "Deleting bank statement: #{@bank_statement.id}" # Debugging
    @bank_statement.destroy
    redirect_to bank_statements_path, notice: "Bank statement deleted successfully."
  rescue ActiveRecord::RecordNotFound
    redirect_to bank_statements_path, alert: "Bank statement not found."
  end

  private

  def bank_statement_params
    params.require(:bank_statement).permit(:file)
  end
end
