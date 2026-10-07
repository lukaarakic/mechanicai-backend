# Cleans up billing and personal data when a user closes their account.
class AccountClosure
  def initialize(account)
    @account = account
  end

  def cancel_billing!
    return unless @account.payment_processor&.subscribed?

    @account.payment_processor.subscription.cancel_now!
  end

  # The account row stays (status = closed) so billing records keep their
  # owner, but everything the user entered is removed.
  def scrub_data!
    @account.chats.destroy_all
    @account.cars.destroy_all
    @account.update_columns(first_name: nil, last_name: nil, avatar: nil)
  end
end
