# error_simulator.rb
# A separate file to simulate errors for testing exception capture

class ErrorSimulator
  def self.simulate_database_error
    # Simulate a database connection error
    raise_database_connection_error
  end
  
  private
  
  def self.raise_database_connection_error
    # Deep in the call stack
    perform_database_operation
  end
  
  def self.perform_database_operation
    # Even deeper - this is where the actual error happens
    raise StandardError, "Database connection failed: Connection refused to localhost:5432"
  end
end

# Another example with instance methods
class PaymentProcessor
  def process_payment(amount)
    validate_amount(amount)
    execute_transaction(amount)
  end
  
  private
  
  def validate_amount(amount)
    raise ArgumentError, "Invalid payment amount: #{amount}" if amount <= 0
  end
  
  def execute_transaction(amount)
    # This would normally process the payment
    raise RuntimeError, "Payment gateway timeout after 30 seconds"
  end
end
