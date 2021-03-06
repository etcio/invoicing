# encoding: utf-8

require_relative 'test_helper'
require_relative "support/ledger_item_helper"

## The actual tests
class LedgerItemTest < MiniTest::Unit::TestCase
  def test_total_amount_is_currency_value
    record = MyLedgerItem.find(5)
    assert_equal '$432.10', record.total_amount_formatted
  end

  def test_tax_amount_is_currency_value
    record = MyInvoice.find(1)
    assert_equal '£15.00', record.tax_amount_formatted
  end

  def test_total_amount_negative_debit
    record = MyLedgerItem.find(5)
    assert_equal '−$432.10', record.total_amount_formatted(:debit => :negative, :self_id => record.recipient_id)
    assert_equal '$432.10', record.total_amount_formatted(:debit => :negative, :self_id => record.sender_id)
  end

  def test_total_amount_negative_credit
    record = MyLedgerItem.find(5)
    assert_equal '−$432.10', record.total_amount_formatted(:credit => :negative, :self_id => record.sender_id)
    assert_equal '$432.10', record.total_amount_formatted(:credit => :negative, :self_id => record.recipient_id)
  end

  def test_net_amount
    assert_equal BigDecimal('300'), MyInvoice.find(1).net_amount
  end

  def test_net_amount_nil
    assert_nil MyInvoice.new.net_amount
  end

  def test_net_amount_formatted
    assert_equal '£300.00', MyInvoice.find(1).net_amount_formatted
  end

  def test_sent_by_nil_is_treated_as_self
    assert MyInvoice.find(1).sent_by?(nil)
    assert MyCreditNote.find(3).sent_by?(nil)
  end

  def test_received_by_nil_is_treated_as_self
    assert InvoiceSubtype.find(2).received_by?(nil)
    assert CorporationTaxLiability.find(6).received_by?(nil)
  end

  def test_invoice_from_self_is_debit
    record = MyInvoice.find(1)
    assert_kind_of MyInvoice, record
    assert record.debit?(1)
    assert record.debit?(nil)
  end

  def test_invoice_to_self_is_credit
    record = InvoiceSubtype.find(2)
    assert_kind_of MyInvoice, record
    refute record.debit?(1)
    refute record.debit?(nil)
  end

  def test_invoice_to_customer_is_seen_as_credit_by_customer
    assert !MyInvoice.find(1).debit?(2)
  end

  def test_invoice_from_supplier_is_seen_as_debit_by_supplier
    assert InvoiceSubtype.find(2).debit?(2)
  end

  def test_credit_note_from_self_is_debit
    record = MyCreditNote.find(3)
    assert_kind_of MyCreditNote, record
    assert record.debit?(nil)
    assert record.debit?(1)
  end

  def test_credit_note_to_customer_is_seen_as_credit_by_customer
    refute MyCreditNote.find(3).debit?(2)
  end

  def test_payment_receipt_from_self_is_credit
    record = MyPayment.find(4)
    assert_kind_of MyPayment, record
    refute record.debit?(1)
    refute record.debit?(nil)
  end

  def test_payment_receipt_to_customer_is_seen_as_debit_by_customer
    assert MyPayment.find(4).debit?(2)
  end

  def test_cannot_determine_debit_status_for_uninvolved_party
    assert_raises ArgumentError do
      MyInvoice.find(1).debit?(3)
    end
  end

  def test_assign_uuid_to_new_record
    record = MyInvoice.new
    begin
      UUID
      uuid_gem_available = true
    rescue NameError
      uuid_gem_available = false
    end
    if uuid_gem_available
      assert_match /^[0-9a-f]{8}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{4}\-[0-9a-f]{12}$/, record.uuid
    else
      assert record.uuid.blank?
      puts "Warning: uuid gem not installed -- not testing UUID generation"
    end
  end

  def test_uuid_gem_not_present
    begin
      real_uuid = Object.send(:remove_const, :UUID) rescue nil
      UUIDNotPresentLedgerItem.acts_as_ledger_item
      assert_nil UUIDNotPresentLedgerItem.new.get_class_info.uuid_generator
    ensure
      Object.send(:const_set, :UUID, real_uuid) unless real_uuid.nil?
    end
  end

  def test_must_overwrite_sender_details
    assert_raises RuntimeError do
      OverwrittenMethodsNotPresentLedgerItem.new.sender_details
    end
  end

  def test_must_overwrite_recipient_details
    assert_raises RuntimeError do
      OverwrittenMethodsNotPresentLedgerItem.new.recipient_details
    end
  end

  def test_must_provide_line_items_association
    assert_raises RuntimeError do
      OverwrittenMethodsNotPresentLedgerItem.new.line_items
    end
  end

  def test_calculate_total_amount_for_new_invoice
    invoice = MyInvoice.new(:currency => 'USD')
    invoice.line_items << SuperLineItem.new(:net_amount => 100, :tax_amount => 15)
    invoice.line_items << SubLineItem.new(:net_amount => 10)
    invoice.valid?

    assert_equal BigDecimal('125'), invoice.total_amount
    assert_equal BigDecimal('15'), invoice.tax_amount
  end

  def test_calculate_total_amount_for_updated_invoice
    invoice = MyInvoice.find(9)
    invoice.line_items << SuperLineItem.new(:net_amount => 10, :tax_amount => 1.5)
    invoice.save!

    invoice.reload
    assert_equal BigDecimal('23'), invoice.total_amount
    assert_equal BigDecimal('3'),  invoice.tax_amount
  end

  def test_calculate_total_amount_for_updated_line_item
    # This might occur while an invoice is still open
    invoice = MyInvoice.find(9)
    invoice.line_items[0].net_amount = '20'
    invoice.line_items[0].tax_amount = 3
    invoice.save!

    invoice.reload
    assert_equal BigDecimal('23'), invoice.total_amount
    assert_equal BigDecimal('3'),  invoice.tax_amount
  end

  def test_do_not_overwrite_total_amount_for_payment_without_line_items
    payment = MyPayment.new(:total_amount => 23.45)
    payment.save!

    assert_equal 23.45, payment.reload.total_amount
  end

  def test_find_invoice_subclasses
    assert_equal %w(InvoiceSubtype MyInvoice), MyLedgerItem.select_matching_subclasses(:is_invoice, true).map(&:name).sort
  end

  def test_find_credit_note_subclasses
    assert_equal %w(MyCreditNote), MyLedgerItem.select_matching_subclasses(:is_credit_note, true).map(&:name)
  end

  def test_find_payment_subclasses
    assert_equal %w(MyPayment), MyLedgerItem.select_matching_subclasses(:is_payment, true).map(&:name)
  end

  def test_account_summary
    summary = MyLedgerItem.account_summary(1, 2)
    assert_equal [:GBP], summary.keys
    assert_equal BigDecimal('257.50'),  summary[:GBP].sales
    assert_equal BigDecimal('141.97'),  summary[:GBP].purchases
    assert_equal BigDecimal('256.50'),  summary[:GBP].sale_receipts
    assert_equal BigDecimal('0.00'),    summary[:GBP].purchase_payments
    assert_equal BigDecimal('-140.97'), summary[:GBP].balance
  end

  def test_account_summary_with_scope
    conditions = ["issue_date >= ? AND issue_date < ?", DateTime.parse('2008-01-01'), DateTime.parse('2009-01-01')]
    summary = MyLedgerItem.where(conditions).account_summary(1, 2)
    assert_equal BigDecimal('257.50'), summary[:GBP].sales
    assert_equal BigDecimal('0.00'),   summary[:GBP].purchases
    assert_equal BigDecimal('256.50'), summary[:GBP].sale_receipts
    assert_equal BigDecimal('0.00'),   summary[:GBP].purchase_payments
    assert_equal BigDecimal('1.00'),   summary[:GBP].balance
  end

  def test_account_summaries
    summaries = MyLedgerItem.account_summaries(2)
    assert_equal [1, 3], summaries.keys
    assert_equal [:GBP], summaries[1].keys
    assert_equal BigDecimal('257.50'),  summaries[1][:GBP].purchases
    assert_equal BigDecimal('141.97'),  summaries[1][:GBP].sales
    assert_equal BigDecimal('256.50'),  summaries[1][:GBP].purchase_payments
    assert_equal BigDecimal('0.00'),    summaries[1][:GBP].sale_receipts
    assert_equal BigDecimal('140.97'),  summaries[1][:GBP].balance
    assert_equal [:USD], summaries[3].keys
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].purchases
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].sales
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].purchase_payments
    assert_equal BigDecimal('432.10'),  summaries[3][:USD].sale_receipts
    assert_equal BigDecimal('-432.10'), summaries[3][:USD].balance
  end

  def test_account_summaries_with_scope
    conditions = ["issue_date < ?", DateTime.parse('2008-07-01')]
    summaries = MyLedgerItem.where(conditions).account_summaries(2)
    assert_equal [1, 3], summaries.keys
    assert_equal [:GBP], summaries[1].keys
    assert_equal BigDecimal('315.00'),  summaries[1][:GBP].purchases
    assert_equal BigDecimal('0.00'),    summaries[1][:GBP].sales
    assert_equal BigDecimal('0.00'),    summaries[1][:GBP].purchase_payments
    assert_equal BigDecimal('0.00'),    summaries[1][:GBP].sale_receipts
    assert_equal BigDecimal('-315.00'), summaries[1][:GBP].balance
    assert_equal [:USD], summaries[3].keys
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].purchases
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].sales
    assert_equal BigDecimal('0.00'),    summaries[3][:USD].purchase_payments
    assert_equal BigDecimal('432.10'),  summaries[3][:USD].sale_receipts
    assert_equal BigDecimal('-432.10'), summaries[3][:USD].balance
  end

  def test_account_summary_over_all_others
    summary = MyLedgerItem.account_summary(1)
    assert_equal [:GBP], summary.keys
    assert_equal BigDecimal('257.50'),     summary[:GBP].sales
    assert_equal BigDecimal('666808.63'),  summary[:GBP].purchases
    assert_equal BigDecimal('256.50'),     summary[:GBP].sale_receipts
    assert_equal BigDecimal('0.00'),       summary[:GBP].purchase_payments
    assert_equal BigDecimal('-666807.63'), summary[:GBP].balance
  end

  def test_account_summary_with_include_open_option
    summary = MyLedgerItem.account_summary(1, nil, :with_status => %w(open closed cleared))
    assert_equal [:GBP], summary.keys
    assert_equal BigDecimal('269.00'),     summary[:GBP].sales
    assert_equal BigDecimal('666808.63'),  summary[:GBP].purchases
    assert_equal BigDecimal('256.50'),     summary[:GBP].sale_receipts
    assert_equal BigDecimal('0.00'),       summary[:GBP].purchase_payments
    assert_equal BigDecimal('-666796.13'), summary[:GBP].balance
  end

  def test_account_summary_to_s
    assert_equal "sales = £257.50; purchases = £666,808.63; sale_receipts = £256.50; " +
      "purchase_payments = £0.00; balance = −£666,807.63", MyLedgerItem.account_summary(1)[:GBP].to_s
  end

  def test_account_summary_formatting
    summary = MyLedgerItem.account_summary(1, 2)
    assert_equal [:GBP], summary.keys
    assert_equal '£257.50',  summary[:GBP].sales_formatted
    assert_equal '£141.97',  summary[:GBP].purchases_formatted
    assert_equal '£256.50',  summary[:GBP].sale_receipts_formatted
    assert_equal '£0.00',    summary[:GBP].purchase_payments_formatted
    assert_equal '−£140.97', summary[:GBP].balance_formatted
  end

  def test_account_summary_object_call_unknown_method
    assert_raises NoMethodError do
      MyLedgerItem.account_summary(1, 2)[:GBP].this_method_does_not_exist
    end
  end

  def test_sender_recipient_name_map_all
    expected_info = {
      1 => 'Unlimited Limited',
      2 => 'Lovely Customer Inc.',
      3 => 'I drink milk',
      4 => 'The taxman'
    }

    assert_equal expected_info, MyLedgerItem.sender_recipient_name_map([1, 2, 3, 4])
  end

  def test_sender_recipient_name_map_subset
    expected_info = {1 => 'Unlimited Limited', 3 => 'I drink milk'}
    assert_equal expected_info, MyLedgerItem.sender_recipient_name_map([1, 3])
  end

  def test_sent_by_scope
    assert_equal [2, 5], MyLedgerItem.sent_by(2).pluck(:id).sort
  end

  def test_received_by_scope
    actual_ids = MyLedgerItem.received_by(2).pluck(:id).sort
    assert_equal [1, 3, 4, 7, 8, 9, 10, 11], actual_ids
  end

  def test_sent_or_received_by_scope
    acutal_ids = MyLedgerItem.sent_or_received_by(2).pluck(:id).sort
    assert_equal [1, 2, 3, 4, 5, 7, 8, 9, 10, 11], acutal_ids
  end

  def test_in_effect_scope
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], MyLedgerItem.pluck(:id).sort
    assert_equal [1, 2, 3, 4, 5, 6, 11], MyLedgerItem.in_effect.pluck(:id).sort
  end

  def test_open_or_pending_scope
    assert_equal [8, 9], MyLedgerItem.open_or_pending.pluck(:id).sort
  end

  def test_due_at_scope
    jan_30_ids = MyLedgerItem.due_at(Time.zone.parse('2009-01-30')).pluck(:id)
    assert_equal [1, 3, 4, 7, 8, 10, 11], jan_30_ids

    jan_31_ids = MyLedgerItem.due_at(Time.zone.parse('2009-01-31')).pluck(:id)
    assert_equal [1, 2, 3, 4, 7, 8, 10, 11], jan_31_ids
  end

  def test_sorted_scope
    sorted_ids = MyLedgerItem.sorted(:issue_date).pluck(:id)
    assert_equal [5, 1, 4, 3, 8, 2, 6, 7, 9, 10, 11], sorted_ids
  end

  def test_sorted_scope_with_non_existent_column
    sorted_ids = MyLedgerItem.sorted(:this_column_does_not_exist).pluck(:id)
    assert_equal [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], sorted_ids
  end

  def test_exclude_empty_invoices_scope
    empty_invoice_ids = MyLedgerItem.exclude_empty_invoices.pluck(:id)
    assert_equal [4, 7, 8, 11], empty_invoice_ids
  end
end
