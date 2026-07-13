import 'locale_provider.dart';

// Global accessor — use as S.nav.bookings, S.status.confirmed, etc.
// Reads appLocale, which is updated synchronously when locale toggles,
// so every widget that watches localeProvider gets the right value on rebuild.
AppStrings get S => appLocale == 'am' ? _am : _en;

final _en = AppStrings._en();
final _am = AppStrings._am();

class AppStrings {
  final NavStrings nav;
  final CommonStrings common;
  final StatusStrings status;
  final ProfileStrings profile;
  final BookingsStrings bookings;
  final BookingDetailStrings bookingDetail;
  final NewBookingStrings newBooking;
  final OperationsStrings operations;
  final CustomersStrings customers;
  final ItemsStrings items;
  final SettingsStrings settings;
  final AuthStrings auth;
  final ModifyStrings modify;
  final ReportsStrings reports;
  final DepositsStrings deposits;
  final PaymentsStrings payments;

  const AppStrings({
    required this.nav,
    required this.common,
    required this.status,
    required this.profile,
    required this.bookings,
    required this.bookingDetail,
    required this.newBooking,
    required this.operations,
    required this.customers,
    required this.items,
    required this.settings,
    required this.auth,
    required this.modify,
    required this.reports,
    required this.deposits,
    required this.payments,
  });

  factory AppStrings._en() => const AppStrings(
    nav: NavStrings(
      bookings: 'Bookings', newBooking: 'New Booking',
      operations: 'Operations', customers: 'Customers',
      settings: 'Settings', items: 'Items', categories: 'Categories',
      staff: 'Staff', branches: 'Branches', reports: 'Reports',
      logout: 'Sign out', logoutConfirm: 'Sign out?',
      logoutMessage: 'You will need to sign in again.',
      logoutConfirmBtn: 'Sign out',
      activeBranch: 'Active Branch',
      payments: 'Payment History', deposits: 'Security Deposits',
    ),
    common: CommonStrings(
      search: 'Search', clear: 'Clear', save: 'Save', cancel: 'Cancel',
      delete: 'Delete', edit: 'Edit', create: 'Create', add: 'Add',
      confirm: 'Confirm', back: 'Back', refresh: 'Refresh',
      loading: 'Loading…', noData: 'No data found',
      notes: 'Notes', phone: 'Phone', altPhone: 'Alt. Phone',
      branch: 'Branch', date: 'Date', name: 'Name',
      actions: 'Actions', status: 'Status',
      retry: 'Retry', close: 'Close', yes: 'Yes', no: 'No',
      tapToSelect: 'Tap to select', optional: '(optional)',
    ),
    status: StatusStrings(
      confirmed: 'Confirmed', pickedUp: 'Picked Up',
      returned: 'Returned', cancelled: 'Cancelled',
      active: 'Active', pending: 'Pending',
      available: 'Available', booked: 'Booked',
      maintenance: 'Maintenance', unavailable: 'Unavailable',
      cleaning: 'Cleaning',
    ),
    profile: ProfileStrings(
      fullName: 'Full Name', firstName: 'First Name', lastName: 'Last Name',
      updateName: 'Update Name', emailAddress: 'Email Address',
      newEmail: 'New Email', updateEmail: 'Update Email',
      password: 'Password', currentPassword: 'Current Password',
      newPassword: 'New Password', confirmPassword: 'Confirm Password',
      updatePassword: 'Update Password',
      nameRequired: 'Both names are required.',
      nameUpdated: 'Name updated.',
      failName: 'Failed to update name.',
      emailRequired: 'Enter a new email.',
      emailUpdated: 'Email updated.',
      failEmail: 'Failed to update email.',
      passRequired: 'Fill all password fields.',
      passMismatch: 'Passwords do not match.',
      passShort: 'Password must be at least 6 characters.',
      passUpdated: 'Password updated.',
      failPass: 'Failed to update password.',
      roleSuperAdmin: 'Super Admin',
      roleShopAdmin: 'Shop Admin',
      roleBranchManager: 'Branch Manager',
      roleStaff: 'Staff',
      editProfile: 'Edit Profile',
      tabName: 'Name', tabEmail: 'Email', tabPassword: 'Password',
      savedSuccessfully: 'Saved successfully',
    ),
    bookings: BookingsStrings(
      title: 'Bookings', allStatuses: 'All',
      searchHint: 'Search by name, phone or invoice…',
      total: 'total', noBookings: 'No bookings found',
      tryDifferent: 'Try a different search or filter',
      pickup: 'Pickup', returnDate: 'Return',
      balance: 'Balance', invoice: 'Invoice',
      modifyBooking: 'Modify Booking', editCustomerInfo: 'Edit Customer Info',
      markPickedUp: 'Mark as Picked Up', markReturned: 'Mark as Returned',
      cancelBooking: 'Cancel Booking', recordPayment: 'Record Payment',
      downloadPdf: 'Download PDF',
    ),
    bookingDetail: BookingDetailStrings(
      financialSummary: 'Financial Summary',
      totalAgreed: 'Total Agreed', totalPaid: 'Total Paid',
      balanceDue: 'Balance Due', securityDeposit: 'Security Deposit',
      held: 'held', depositReturned: 'Returned',
      depositDeduction: 'Deduction', excessCharge: 'Excess Charge',
      customer: 'Customer', phone: 'Phone', altPhone: 'Alt. Phone',
      pickupDate: 'Pickup', returnDate: 'Return', returnedOn: 'Returned On',
      notes: 'Notes', branch: 'Branch', items: 'Items',
      changeHistory: 'Change History', noChanges: 'No changes recorded yet.',
      itemsRented: 'Items Rented', qty: 'qty',
      markPickedUp: 'Mark as Picked Up', markReturned: 'Mark as Returned',
      cancel: 'Cancel Booking', pay: 'Record Payment',
      modify: 'Modify Booking', pdf: 'PDF', edit: 'Edit Customer Info',
      cancelledNote: 'This booking was cancelled.',
      advancePayments: 'Advance Payments', noPayments: 'No payments recorded.',
      refundAmount: 'Refund Amount',
      depositStatus: 'Deposit Status',
      returned: 'returned', notReturned: 'not yet returned',
      collected: 'Collected',
      financials: 'Financials',
      paid: 'Paid', balance: 'Balance',
      cancellationSummary: 'Cancellation Summary',
      netKept: 'Net Kept', advancePaid: 'Advance Paid',
      refunded: 'Refunded', noRefundGiven: 'No refund given',
      damageDeduction: 'Damage deduction',
      rentalPeriod: 'Rental Period', duration: 'Duration', reason: 'Reason',
      allReturned: 'All Returned', returnItem: 'Return',
      depositPartial: 'Partial', depositKeptDamage: 'Kept / Damage',
      depositPending: 'Pending',
      paymentCollection: 'Payment Collection',
      amountCollected: 'Amount collected',
      securityDepositOptional: 'Security deposit (optional)',
      confirmPickup: 'Confirm Pickup',
      finalPayment: 'Final Payment', itemCondition: 'Item Condition',
      noDamage: 'No Damage', damageFound: 'Damage Found',
      totalDamageAmount: 'Total damage amount',
      describeTheDamage: 'Describe the damage',
      completeReturn: 'Complete Return',
      fullRefund: 'Full Refund', noRefund: 'No Refund', custom: 'Custom',
      customerReceives: 'Customer receives', shopKeeps: 'Shop keeps',
      damageAssessment: 'Damage Assessment',
      noDepositCollected: 'No deposit collected — you can still record damage if applicable.',
      damageRecorded: 'Damage Recorded',
      cancellationReason: 'Cancellation Reason (optional)',
      amountToCollect: 'Amount to collect', fillBalance: 'Fill balance',
      editBooking: 'Edit Booking', paymentSection: 'Payment',
      totalAgreedPrice: 'Total agreed price',
      totalAdvancePaid: 'Total advance paid',
      saveChanges: 'Save Changes',
      rentalAgreement: 'Rental Agreement',
      includeSignatureLines: 'Include signature lines',
      signatureLinesHint: 'Adds acknowledgment fields at the bottom',
      saveToDevice: 'Save to Device', share: 'Share',
      failedToLoad: 'Failed to load booking',
      itemMarkedReturnedMsg: 'Item marked as returned',
      paymentRecordedMsg: 'Payment recorded',
      bookingModifiedMsg: 'Booking modified successfully',
      bookingUpdatedMsg: 'Booking updated',
      pickedUpMsg: 'Picked up — booking is now active',
      returnedMsg: 'Returned — booking completed',
      cancelledMsg: 'Booking cancelled',
      enterValidAmountMsg: 'Enter a valid amount',
      collectButton: 'Collect',
      staffFallback: 'Staff',
      collectedLog: 'collected', refundedLog: 'refunded',
      enterDamageAmountMsg: 'Enter damage amount',
      unitLabel: 'Unit',
    ),
    newBooking: NewBookingStrings(
      title: 'New Booking',
      stepItems: 'Items & Dates', stepPayment: 'Payment', stepReview: 'Review',
      customerInfo: 'Customer Info',
      firstName: 'First Name', lastName: 'Last Name',
      phone: 'Phone Number', altPhone: 'Alt. Phone',
      pickupDate: 'Pickup Date', returnDate: 'Return Date',
      dateNote: 'Rental period starts from pickup date — Day 1 = pickup day',
      searchCustomer: 'Find existing customer by phone',
      searchItems: 'Search items…',
      noItemsFound: 'No matching items found',
      noBranch: 'Select a branch from settings before creating a booking.',
      totalAgreed: 'Total Agreed Price',
      advancePayment: 'Advance Payment',
      securityDeposit: 'Security Deposit',
      balanceDue: 'Balance Due',
      createBooking: 'Create Booking',
      confirmCreate: 'Confirm & Create',
      confirmTitle: 'Confirm Booking',
      successTitle: 'Booking Created!',
      invoiceNumber: 'Invoice Number',
      viewDetail: 'View Details',
      noItemsSelected: 'Add at least one item',
      selectDates: 'Select both pickup and return dates',
      next: 'Next', back: 'Back',
      selectedItems: 'Selected Items', availableItems: 'Available Items',
      rentalDays: 'rental day', rentalDaysPlural: 'rental days',
      existingCustomer: 'Existing Customer',
      newCustomer: 'New Customer',
      noCustomerFound: 'Customer not found',
      saveAsNew: 'Save as new customer',
      typeDigits: 'Type at least 2 digits',
      minSuggested: 'Min. suggested:',
      useMin: 'Use',
      unitsAvail: 'available',
      clearOrder: 'Clear',
      order: 'Order',
      payment: 'Payment',
      availability: 'Availability',
      saveCustomer: 'Save Customer',
      titleDates: 'Rental Dates', titleItems: 'Select Items', titleCustomer: 'Customer',
      whenIsRental: 'When is the rental?', selectPickupReturn: 'Select pickup and return dates',
      whoIsRenting: 'Who is renting?', searchByPhone: 'Search by phone number',
      enterPhone: 'Enter phone number…', noItemsAvailable: 'No items available',
      expected: 'Expected', saveAsNewBtn: 'Save as New', blacklisted: 'Blacklisted',
      saveBefore: 'Please save the customer before continuing',
      selectOrSave: 'Please select or save a customer',
      enterValidTotal: 'Enter a valid total amount',
      advanceExceedsTotal: 'Advance payment cannot exceed the total agreed price',
      bookingCreated: 'Booking created', bookingCreatedSuccess: 'Booking created successfully',
      firstNamePhoneRequired: 'First name and phone number are required',
      branchLabel: 'Branch', dayRental: 'day rental', daysRental: 'days rental',
      paymentSetup: 'Payment Setup', setAgreedPrice: 'Set agreed price and advance',
      cannotExceed: 'Cannot exceed total agreed price', continueBtn: 'Continue',
      reviewConfirm: 'Review & Confirm', doubleCheck: 'Double-check before submitting',
      sectionDates: 'DATES', sectionItems: 'ITEMS', sectionCustomer: 'CUSTOMER',
      sectionPayment: 'PAYMENT', labelPickup: 'Pickup', labelReturn: 'Return',
      labelDuration: 'Duration', labelName: 'Name', labelPhone: 'Phone',
      labelAltPhone: 'Alt Phone', labelTotalAgreed: 'Total Agreed', labelAdvance: 'Advance',
      searchItemHint: 'Search by name or code…', unitType: 'type', unitTypes: 'types',
    ),
    operations: OperationsStrings(
      title: 'Operations',
      todayPickups: "Today's Pickups",
      dueReturns: 'Due Returns',
      overdue: 'Overdue',
      outstanding: 'Outstanding',
      noPickups: 'No pickups today',
      noDueReturns: 'No returns due today',
      noOverdue: 'No overdue returns',
      noOutstanding: 'No outstanding balances',
      dueBackToday: 'Due back today',
      pickedUp: 'Picked up',
      overdueReturn: 'Overdue return',
      dayOverdue: 'day overdue', daysOverdue: 'days overdue',
      wasDue: 'Was due',
      totalOutstanding: 'Total Outstanding', remaining: 'remaining',
    ),
    customers: CustomersStrings(
      title: 'Customers', totalCustomers: 'total',
      searchHint: 'Search by name or phone…',
      noCustomers: 'No customers found',
      tryDifferent: 'Try a different search',
      active: 'Active', blacklisted: 'Blacklisted',
      memberSince: 'Member Since', lastBooking: 'Last Booking',
      totalBookings: 'Total Bookings', totalSpent: 'Total Spent',
      totalPaid: 'Total Paid', outstanding: 'Outstanding',
      bookingHistory: 'Booking History',
      blacklistCustomer: 'Blacklist Customer',
      blacklistReason: 'Reason (optional)',
      removeBlacklist: 'Remove from Blacklist',
      deleteCustomer: 'Delete Customer',
      deleteWarning: 'Booking history will be kept. This cannot be undone.',
      customerInfo: 'Customer Info',
      stats: 'Stats', info: 'Info',
      confirmBlacklist: 'Blacklist this customer?',
      confirmRemove: 'Remove from blacklist?',
      confirmDelete: 'Delete customer?',
      blacklistWarning: 'This customer will be flagged on all future bookings.',
      noBookings: 'No bookings yet',
      editCustomer: 'Edit Customer',
      since: 'Since',
      paidLabel: 'Paid', dueLabel: 'due',
      blacklistedCustomer: 'Blacklisted Customer',
      cannotBeUndone: 'This action cannot be undone.',
      failedToSave: 'Failed to save. Please try again.',
      failedToDelete: 'Failed to delete. Please try again.',
    ),
    items: ItemsStrings(
      title: 'Items', addItem: 'Add Item',
      code: 'Code', category: 'Category',
      available: 'Available', unavailable: 'Unavailable',
      noItems: 'No items found',
      searchByCode: 'Search by code or name…',
      qty: 'Qty', minPrice: 'Min Price',
      filterAll: 'All', filterAvailable: 'Available',
      filterBooked: 'Booked', filterCleaning: 'Cleaning',
      noMatch: 'No items match',
      totalUnits: 'Total Units',
      inInventory: 'in inventory',
      unit: 'unit', units: 'units',
      noItemsYet: 'No items yet', tapToAddItem: 'Tap + to add your first item',
      deleteItem: 'Delete Item', perDay: 'per day', editItem: 'Edit Item',
      itemName: 'Item Name', uniqueCode: 'Unique Code', minPriceDay: 'Min Price/Day',
      quantity: 'Quantity', categoryOptional: 'Category (optional)', noCategory: 'No category',
      descriptionOptional: 'Description (optional)', cleaningGap: 'Cleaning Gap',
      cleaningGapSub: 'Block one day between bookings for cleaning',
      nameCodePriceRequired: 'Name, code and price are required', saveChanges: 'Save Changes',
      addCategory: 'Add Category', noCategoriesYet: 'No categories yet',
      tapToAddCategory: 'Tap + to add your first category', deleteCategory: 'Delete Category',
      editCategory: 'Edit Category', newCategory: 'New Category',
      categoryName: 'Category name', nameRequired: 'Name is required',
      createCategory: 'Create Category',
    ),
    settings: SettingsStrings(
      title: 'Settings',
      appSettings: 'App Settings',
      manage: 'Manage',
      reportsSection: 'Reports',
      account: 'Account',
      serverUrl: 'Server URL', serverUrlSub: 'API server address',
      items: 'Items', itemsSub: 'Manage rental inventory',
      categories: 'Categories', categoriesSub: 'Organise item categories',
      staff: 'Staff', staffSub: 'Manage staff accounts',
      branches: 'Branches', branchesSub: 'Manage shop branches',
      reports: 'Reports', reportsSub: 'Revenue, receivables & item analytics',
      payments: 'Payment History', paymentsSub: 'Full financial ledger',
      deposits: 'Security Deposits', depositsSub: 'Deposit lifecycle & damage tracking',
      signOut: 'Sign out', signOutSub: 'Sign out of your account',
      signOutConfirm: 'Sign out', signOutMessage: 'Are you sure you want to sign out?',
      language: 'Language / ቋንቋ',
      languageEn: 'English — Gregorian calendar',
      languageAm: 'አማርኛ — ኢትዮጵያ ቀን',
      activeBranch: 'Active Branch',
      addStaff: 'Add Staff', noStaffYet: 'No staff yet',
      tapToAddStaff: 'Tap + to add your first staff member',
      addStaffMember: 'Add Staff Member',
      addStaffSubtitle: 'Create a new branch manager or staff account',
      banned: 'Banned', ban: 'Ban', unban: 'Unban', staffRoleLabel: 'Role',
      staffRequired: 'Required', validEmailRequired: 'Valid email required',
      minSixChars: 'Min 6 characters', selectBranch: 'Select a branch',
      createAccount: 'Create Account', pleaseSelectBranch: 'Please select a branch',
      bannedMsg: 'banned', unbannedMsg: 'unbanned',
      switchBranch: 'Switch Branch', noBranchesAvailable: 'No branches available',
      addBranch: 'Add Branch', noBranchesYet: 'No branches yet',
      tapToAddBranch: 'Tap + to create your first branch',
      noAddressPhone: 'No address or phone added',
      editBranch: 'Edit Branch', newBranch: 'New Branch',
      branchNameLabel: 'Branch Name *', addressOptional: 'Address (optional)',
      phoneOptional: 'Phone (optional)', createBranch: 'Create Branch',
      branchNameRequired: 'Name is required',
    ),
    auth: AuthStrings(
      signIn: 'Sign In', email: 'Email address', password: 'Password',
      serverUrl: 'Server URL (e.g. http://192.168.1.1:8080)',
      configureServer: 'Configure server URL',
      hideServer: 'Hide server settings',
      invalidCredentials: 'Invalid email or password',
      subtitle: 'Rental Management',
    ),
    modify: ModifyStrings(
      title: 'Modify Booking',
      stepItems: 'Items & Dates', stepPayment: 'Payment', stepReview: 'Review',
      saveChanges: 'Save Changes', cancel: 'Cancel',
      conflictsTitle: 'Items Conflict',
      conflictsMsg: 'Some items exceed availability on the new dates.',
      resolveFirst: 'Resolve conflicts first',
      noItems: 'Add at least one item',
      fetchError: 'Failed to load items. Tap retry.',
      notes: 'Notes (optional)', notesHint: 'Any notes about this change…',
      additionalPayment: 'Additional Payment',
      additionalPaymentHint: 'Amount collected for this change (0 if none)',
      pickup: 'Pickup', returnDate: 'Return', days: 'days',
      searchItems: 'Search items…',
      filterAll: 'All',
      onlyNAvailable: 'Only {n} available',
      booked: 'BOOKED',
      summaryTitle: 'Review Changes',
      noChanges: 'No changes detected',
      itemsChanged: 'Items changed',
      datesChanged: 'Dates changed',
      paymentNote: 'Payment collected for this modification',
    ),
    reports: ReportsStrings(
      title: 'Reports',
      outstanding: 'Outstanding', daily: 'Daily', monthly: 'Monthly',
      byItem: 'By Item',
      noData: 'No data for this period',
      selectDate: 'Select a date and tap View',
      selectMonth: 'Select year and month, then tap View',
      year: 'Year', month: 'Month', view: 'View',
      invoice: 'Invoice', customer: 'Customer', phone: 'Phone',
      bookingDate: 'Booking Date', totalPrice: 'Total Price',
      totalPaid: 'Total Paid', balanceDue: 'Balance Due',
      totalBookings: 'Total Bookings', totalRevenue: 'Total Revenue',
      tabOverview: 'Overview', tabRevenue: 'Revenue', tabReceivables: 'Receivables',
      tabItems: 'Items', tabBranches: 'Branches',
      totalRevenueStat: 'Total Revenue', collected: 'Collected',
      bookingsStat: 'Bookings', last12Months: 'Last 12 Months',
      topItemsByRevenue: 'Top Items by Revenue',
      today: 'Today', thisMonth: 'This Month', custom: 'Custom', load: 'Load',
      collectionRate: 'Collection Rate', selectPeriod: 'Select a period to load data.',
      allOutstanding: 'All Outstanding', clearFilter: 'Clear filter',
      noOutstandingBookings: 'No outstanding bookings',
      utilization: 'Utilization', lastMonth: 'Last Month',
      totalAllBranches: 'Total (All Branches)',
      selectPeriodLoad: 'Select a period and tap Load.',
      tryAgain: 'Try again',
    ),
    deposits: DepositsStrings(
      title: 'Security Deposits',
      held: 'Held', returned: 'Returned', deducted: 'Deducted',
      noDeposits: 'No deposits found',
      deposit: 'Deposit', deduction: 'Deduction',
      excessCharge: 'Excess Charge',
      all: 'All', partialKeep: 'Partial Keep', fullKeep: 'Full Keep',
      extraDamage: 'Extra Damage',
      currentlyHeld: 'Currently Held', returnedClean: 'Returned Clean',
      keptForDamage: 'Kept for Damage',
      applyFilters: 'Apply Filters', fromDate: 'From date', toDate: 'To date',
      allBranches: 'All Branches', clear: 'Clear',
      noDepositRecords: 'No deposit records',
      tryAdjusting: 'Try adjusting your filters',
      keptLabel: 'Kept', depositLifecycle: 'Deposit Lifecycle',
      openBooking: 'Open Booking', tryAgain: 'Try again',
      statusPartialKeep: 'Partial Keep', statusFullKeep: 'Full Keep',
      statusExcessDamage: 'Excess Damage',
      depositCollected: 'Deposit Collected', awaitingReturn: 'Awaiting return',
      itemReturned: 'Item Returned', returnedOn: 'Returned on',
      returnDateNotRecorded: 'Return date not recorded',
      fullDepositReturned: 'Full Deposit Returned', remainderReturned: 'Remainder Returned',
      fullDepositKept: 'Full Deposit Kept', extraDamageCollected: 'Extra Damage Collected',
    ),
    payments: PaymentsStrings(
      title: 'Payment History',
      noPayments: 'No payments found',
      advance: 'Advance', additional: 'Additional',
      securityDeposit: 'Security Deposit', refund: 'Refund',
      recordedBy: 'Recorded by',
      subtitle: 'Full financial ledger',
      totalReceived: 'Total Received', totalReturned: 'Total Returned', netCash: 'Net Cash',
      searchHint: 'Search…', clearAll: 'Clear all',
      hideFilters: 'Hide filters', showFilters: 'Show filters',
      all: 'All', noRecords: 'No payment records',
      tryAdjusting: 'Try adjusting your filters',
      paymentsWillAppear: 'Payments will appear here',
      tryAgain: 'Try again', loadMore: 'Load more', ofLabel: 'of',
      damage: 'Damage', depositRefund: 'Deposit Refund', damageCharge: 'Damage Charge',
      initialAdvance: 'Initial Advance', additionalPayment: 'Additional Payment',
      depositReturned: 'Deposit Returned', depositKept: 'Deposit Kept',
      records: 'records', searchHintFull: 'Search invoice, customer, phone…',
      fromDate: 'From date', toDate: 'To date',
      searchPrefix: 'Search', fromPrefix: 'From', toPrefix: 'To',
    ),
  );

  factory AppStrings._am() => const AppStrings(
    nav: NavStrings(
      bookings: 'የተያዙ', newBooking: 'አዲስ ማስያዝ',
      operations: 'የስራ እንቅስቃሴ', customers: 'ደንበኞች',
      settings: 'ቅንብሮች', items: 'እቃዎች', categories: 'ምድቦች',
      staff: 'ሰራተኞች', branches: 'ቅርንጫፎች', reports: 'ሪፖርቶች',
      logout: 'ውጣ', logoutConfirm: 'መውጣት ይፈልጋሉ?',
      logoutMessage: 'እንደገና ለመግባት የመግቢያ መረጃዎን ማስገባት ያስፈልጋል።',
      logoutConfirmBtn: 'ውጣ',
      activeBranch: 'ንቁ ቅርንጫፍ',
      payments: 'የክፍያ ታሪክ', deposits: 'የዋስትና ተቀማጭ',
    ),
    common: CommonStrings(
      search: 'ፈልግ', clear: 'አጽዳ', save: 'አስቀምጥ', cancel: 'ሰርዝ',
      delete: 'ሰርዝ', edit: 'ማስተካከል', create: 'ፍጠር', add: 'ጨምር',
      confirm: 'አረጋግጥ', back: 'ተመለስ', refresh: 'አድስ',
      loading: 'እየጫነ ነው…', noData: 'ምንም መረጃ አልተገኘም',
      notes: 'ማስታወሻዎች', phone: 'ስልክ', altPhone: 'ሌላ ስልክ',
      branch: 'ቅርንጫፍ', date: 'ቀን', name: 'ስም',
      actions: 'ድርጊቶች', status: 'ሁኔታ',
      retry: 'እንደገና ሞክር', close: 'ዝጋ', yes: 'አዎ', no: 'አይደለም',
      tapToSelect: 'ለመምረጥ ይጫኑ', optional: '(አማራጭ)',
    ),
    status: StatusStrings(
      confirmed: 'ተረጋግጧል', pickedUp: 'ተወስዷል',
      returned: 'ተመልሷል', cancelled: 'ተሰርዟል',
      active: 'ንቁ', pending: 'በመጠባበቅ ላይ',
      available: 'ይገኛል', booked: 'ተያዟል',
      maintenance: 'ጥገና ላይ', unavailable: 'አይገኝም',
      cleaning: 'በጽዳት ላይ',
    ),
    profile: ProfileStrings(
      fullName: 'ሙሉ ስም', firstName: 'ስም', lastName: 'የአባት ስም',
      updateName: 'ስም ይቀይሩ', emailAddress: 'ኢሜይል አድራሻ',
      newEmail: 'አዲስ ኢሜይል', updateEmail: 'ኢሜይል ይቀይሩ',
      password: 'ፓስዎርድ', currentPassword: 'የአሁን ፓስዎርድ',
      newPassword: 'አዲስ ፓስዎርድ', confirmPassword: 'አዲሱን ፓስዎርድ አረጋግጥ',
      updatePassword: 'ፓስዎርድ ይቀይሩ',
      nameRequired: 'ሁለቱም ስሞች ያስፈልጋሉ።',
      nameUpdated: 'ስም ተዘምኗል።',
      failName: 'ስምን ማዘመን አልተቻለም።',
      emailRequired: 'አዲስ ኢሜይል ያስገቡ።',
      emailUpdated: 'ኢሜይል ተዘምኗል።',
      failEmail: 'ኢሜይልን ማዘመን አልተቻለም።',
      passRequired: 'ሁሉንም ፓስዎርድ ሜዳዎች ይሙሉ።',
      passMismatch: 'ፓስዎርዶቹ አይዛመዱም።',
      passShort: 'ፓስዎርዱ ቢያንስ 6 ፊደሎች መሆን አለበት።',
      passUpdated: 'ፓስዎርዱ ተዘምኗል።',
      failPass: 'ፓስዎርዱን ማዘመን አልተቻለም።',
      roleSuperAdmin: 'ዋና አስተዳዳሪ',
      roleShopAdmin: 'የሱቅ አስተዳዳሪ',
      roleBranchManager: 'የቅርንጫፍ ሥራ አስኪያጅ',
      roleStaff: 'ሰራተኛ',
      editProfile: 'መገለጫ ያስተካክሉ',
      tabName: 'ስም', tabEmail: 'ኢሜይል', tabPassword: 'ፓስዎርድ',
      savedSuccessfully: 'ተቀምጧል',
    ),
    bookings: BookingsStrings(
      title: 'የተያዙ', allStatuses: 'ሁሉም',
      searchHint: 'በስም፣ ስልክ ወይም ደረሰኝ ቁጥር ፈልግ…',
      total: 'ጠቅላላ', noBookings: 'ምንም የተያዙ አልተገኙም',
      tryDifferent: 'ሌላ ፍለጋ ወይም ማጣሪያ ይሞክሩ',
      pickup: 'መውሰጃ', returnDate: 'መመለሻ',
      balance: 'ቀሪ ሂሳብ', invoice: 'ደረሰኝ',
      modifyBooking: 'ማስያዝ ቀይር', editCustomerInfo: 'የደንበኛ መረጃ ያስተካክሉ',
      markPickedUp: 'እንደተወሰደ ምልክት አድርግ',
      markReturned: 'እንደተመለሰ ምልክት አድርግ',
      cancelBooking: 'ማስያዝ ሰርዝ', recordPayment: 'ክፍያ መዝግብ',
      downloadPdf: 'ፒዲኤፍ ውርድ',
    ),
    bookingDetail: BookingDetailStrings(
      financialSummary: 'የፋይናንስ ማጠቃለያ',
      totalAgreed: 'ጠቅላላ ዋጋ', totalPaid: 'ጠቅላላ ተከፍሏል',
      balanceDue: 'ቀሪ ሂሳብ', securityDeposit: 'የዋስትና ተቀማጭ',
      held: 'ተይዟል', depositReturned: 'ተመልሷል',
      depositDeduction: 'ቅናሽ', excessCharge: 'ተጨማሪ ክፍያ',
      customer: 'ደንበኛ', phone: 'ስልክ', altPhone: 'ሌላ ስልክ',
      pickupDate: 'መውሰጃ', returnDate: 'መመለሻ', returnedOn: 'የተመለሰበት',
      notes: 'ማስታወሻዎች', branch: 'ቅርንጫፍ', items: 'እቃዎች',
      changeHistory: 'የለውጥ ታሪክ', noChanges: 'ምንም ለውጦች አልተመዘገቡም።',
      itemsRented: 'የተከራዩ እቃዎች', qty: 'ብዛት',
      markPickedUp: 'እንደተወሰደ ምልክት አድርግ',
      markReturned: 'እንደተመለሰ ምልክት አድርግ',
      cancel: 'ማስያዝ ሰርዝ', pay: 'ክፍያ መዝግብ',
      modify: 'ማስያዝ ቀይር', pdf: 'ፒዲኤፍ', edit: 'የደንበኛ መረጃ ያስተካክሉ',
      cancelledNote: 'ይህ ማስያዝ ተሰርዟል።',
      advancePayments: 'የቅድሚያ ክፍያዎች', noPayments: 'ምንም ክፍያዎች አልተመዘገቡም።',
      refundAmount: 'የተመላሽ ገንዘብ',
      depositStatus: 'የተቀማጭ ሁኔታ',
      returned: 'ተመልሷል', notReturned: 'ገና አልተመለሰም',
      collected: 'ተሰብስቧል',
      financials: 'ፋይናንስ',
      paid: 'ተከፍሏል', balance: 'ቀሪ ሂሳብ',
      cancellationSummary: 'የሰርዛ ማጠቃለያ',
      netKept: 'ተይዞ የቀረ', advancePaid: 'የቅድሚያ ክፍያ',
      refunded: 'ተመልሷል', noRefundGiven: 'ምንም ተመላሽ አልተሰጠም',
      damageDeduction: 'የጉዳት ቅናሽ',
      rentalPeriod: 'የኪራይ ጊዜ', duration: 'ቆይታ', reason: 'ምክንያት',
      allReturned: 'ሁሉም ተመልሷቸዋል', returnItem: 'መለስ',
      depositPartial: 'ከፊል', depositKeptDamage: 'ተይዟል / ጉዳት',
      depositPending: 'በመጠባበቅ ላይ',
      paymentCollection: 'ክፍያ መሰብሰቢያ',
      amountCollected: 'የተሰበሰበ ገንዘብ',
      securityDepositOptional: 'የዋስትና ተቀማጭ (አስፈላጊ ካልሆነ)',
      confirmPickup: 'ፒክአፕ አረጋግጥ',
      finalPayment: 'የመጨረሻ ክፍያ', itemCondition: 'የዕቃ ሁኔታ',
      noDamage: 'ምንም ጉዳት የለም', damageFound: 'ጉዳት ተገኝቷል',
      totalDamageAmount: 'ጠቅላላ የጉዳት መጠን',
      describeTheDamage: 'ጉዳቱን ይግለጹ',
      completeReturn: 'ተመላሽ ጨርስ',
      fullRefund: 'ሙሉ ተመላሽ', noRefund: 'ምንም ተመላሽ', custom: 'ብጁ',
      customerReceives: 'ደንበኛ የሚያጋኝ', shopKeeps: 'ሱቅ ያቆያል',
      damageAssessment: 'የጉዳት ምዘና',
      noDepositCollected: 'ምንም ተቀማጭ አልተሰበሰበም — ጉዳት ካለ መዝግብ።',
      damageRecorded: 'ጉዳት ተምዝጋቢ',
      cancellationReason: 'የሰርዛ ምክንያት (አስፈላጊ ካልሆነ)',
      amountToCollect: 'የሚሰበሰብ ገንዘብ', fillBalance: 'ሂሳቡን ሙላ',
      editBooking: 'ቦኪንግ ያስተካክሉ', paymentSection: 'ክፍያ',
      totalAgreedPrice: 'ጠቅላላ የተስማሙ ዋጋ',
      totalAdvancePaid: 'ጠቅላላ የቅድሚያ ክፍያ',
      saveChanges: 'ለውጦች አስቀምጥ',
      rentalAgreement: 'የኪራይ ስምምነት',
      includeSignatureLines: 'የፊርማ መስመሮች አካትት',
      signatureLinesHint: 'ምስክርነት ሜዳዎችን ከታች ያክላል',
      saveToDevice: 'ወደ መሳሪያ ያስቀምጡ', share: 'አካፍል',
      failedToLoad: 'ቦኪንጉን መጫን አልተቻለም',
      itemMarkedReturnedMsg: 'ዕቃ እንደተመለሰ ምልክት ተደርጎበታል',
      paymentRecordedMsg: 'ክፍያ ተምዝጋቧል',
      bookingModifiedMsg: 'ቦኪንጉ ተቀይሯል',
      bookingUpdatedMsg: 'ቦኪንጉ ታድሷል',
      pickedUpMsg: 'ተወስዷል — ቦኪንጉ አሁን ንቁ ነው',
      returnedMsg: 'ተመልሷል — ቦኪንጉ ተጠናቋል',
      cancelledMsg: 'ቦኪንጉ ተሰርዟል',
      enterValidAmountMsg: 'ትክክለኛ ዋጋ ያስገቡ',
      collectButton: 'ሰብስብ',
      staffFallback: 'ሰራተኛ',
      collectedLog: 'ተሰብስቧል', refundedLog: 'ተመልሷል',
      enterDamageAmountMsg: 'የጉዳት መጠን ያስገቡ',
      unitLabel: 'ቁጥር',
    ),
    newBooking: NewBookingStrings(
      title: 'አዲስ ማስያዝ',
      stepItems: 'እቃዎች እና ቀናት', stepPayment: 'ክፍያ', stepReview: 'ማጠቃለያ',
      customerInfo: 'የደንበኛ መረጃ',
      firstName: 'ስም', lastName: 'የአባት ስም',
      phone: 'ስልክ ቁጥር', altPhone: 'ሌላ ስልክ',
      pickupDate: 'መውሰጃ ቀን', returnDate: 'መመለሻ ቀን',
      dateNote: 'የኪራይ ጊዜ ከመውሰጃ ቀን ይጀምራል — ቀን 1 = መውሰጃ ቀን',
      searchCustomer: 'ነባር ደንበኛ በስልክ ቁጥር ፈልግ',
      searchItems: 'እቃዎች ፈልግ…',
      noItemsFound: 'የሚዛመድ ምርት አልተገኘም',
      noBranch: 'ቦኪንግ ከመፍጠርዎ በፊት ቅርንጫፍ ይምረጡ።',
      totalAgreed: 'ጠቅላላ የተስማሙ ዋጋ',
      advancePayment: 'የቅድሚያ ክፍያ',
      securityDeposit: 'የዋስትና ተቀማጭ',
      balanceDue: 'ቀሪ ክፍያ',
      createBooking: 'ማስያዝ ፍጠር',
      confirmCreate: 'አረጋግጥ እና ፍጠር',
      confirmTitle: 'ቦኪንግ አረጋግጥ',
      successTitle: 'ቦኪንግ ተፈጥሯል!',
      invoiceNumber: 'ደረሰኝ ቁጥር',
      viewDetail: 'ዝርዝር ይመልከቱ',
      noItemsSelected: 'ቢያንስ አንድ እቃ ይምረጡ',
      selectDates: 'ሁለቱንም ቀናት ይምረጡ',
      next: 'ቀጣይ', back: 'ተመለስ',
      selectedItems: 'የተመረጡ እቃዎች', availableItems: 'ያሉ እቃዎች',
      rentalDays: 'ቀን ኪራይ', rentalDaysPlural: 'ቀናት ኪራይ',
      existingCustomer: 'ያለ ደንበኛ',
      newCustomer: 'አዲስ ደንበኛ',
      noCustomerFound: 'ደንበኛ አልተገኘም',
      saveAsNew: 'እንደ አዲስ ደንበኛ አስቀምጥ',
      typeDigits: 'ቢያንስ 2 ቁጥር ፃፍ',
      minSuggested: 'ዝቅተኛ ጠቋሚ:',
      useMin: 'ተጠቀም',
      unitsAvail: 'ይገኛል',
      clearOrder: 'አጽዳ',
      order: 'ትዕዛዝ',
      payment: 'ክፍያ',
      availability: 'ተገኝነት',
      saveCustomer: 'ደንበኛ አስቀምጥ',
      titleDates: 'የኪራይ ቀናት', titleItems: 'እቃዎች ይምረጡ', titleCustomer: 'ደንበኛ',
      whenIsRental: 'ኪራዩ መቼ ነው?', selectPickupReturn: 'መውሰጃ እና መመለሻ ቀናት ይምረጡ',
      whoIsRenting: 'ማን ይከራያል?', searchByPhone: 'በስልክ ቁጥር ፈልግ',
      enterPhone: 'ስልክ ቁጥር ያስገቡ…', noItemsAvailable: 'ምንም እቃዎች አይገኙም',
      expected: 'የሚጠበቅ', saveAsNewBtn: 'እንደ አዲስ አስቀምጥ', blacklisted: 'ጥቁር ዝርዝር',
      saveBefore: 'ደንበኛውን ከማስቀጠልዎ በፊት ያስቀምጡ',
      selectOrSave: 'ደንበኛ ይምረጡ ወይም ያስቀምጡ',
      enterValidTotal: 'ትክክለኛ ጠቅላላ ዋጋ ያስገቡ',
      advanceExceedsTotal: 'ቅድሚያ ክፍያ ጠቅላላ ዋጋን ሊያልፍ አይችልም',
      bookingCreated: 'ቦኪንግ ተፈጥሯል', bookingCreatedSuccess: 'ቦኪንጉ ተፈጥሯል',
      firstNamePhoneRequired: 'ስም እና ስልክ ቁጥር ያስፈልጋሉ',
      branchLabel: 'ቅርንጫፍ', dayRental: 'ቀን ኪራይ', daysRental: 'ቀናት ኪራይ',
      paymentSetup: 'ክፍያ ዝግጅት', setAgreedPrice: 'የተስማሙ ዋጋ እና ቅድሚያ ያስቀምጡ',
      cannotExceed: 'ጠቅላላ ዋጋን ሊያልፍ አይችልም', continueBtn: 'ቀጥል',
      reviewConfirm: 'ፈትሽ እና አረጋግጥ', doubleCheck: 'ከማስገባትዎ በፊት ያረጋግጡ',
      sectionDates: 'ቀናት', sectionItems: 'እቃዎች', sectionCustomer: 'ደንበኛ',
      sectionPayment: 'ክፍያ', labelPickup: 'መውሰጃ', labelReturn: 'መመለሻ',
      labelDuration: 'ጊዜ', labelName: 'ስም', labelPhone: 'ስልክ',
      labelAltPhone: 'ሌላ ስልክ', labelTotalAgreed: 'ጠቅላላ የተስማሙ', labelAdvance: 'ቅድሚያ',
      searchItemHint: 'በስም ወይም ኮድ ፈልግ…', unitType: 'አይነት', unitTypes: 'አይነቶች',
    ),
    operations: OperationsStrings(
      title: 'ስራዎች',
      todayPickups: 'የዛሬ መውሰጃዎች',
      dueReturns: 'ሊመለሱ የሚገባቸው',
      overdue: 'ጊዜ ያለፈባቸው',
      outstanding: 'ያልተከፈሉ ሂሳቦች',
      noPickups: 'ዛሬ ምንም ለመውሰድ የለም',
      noDueReturns: 'ዛሬ ሊመለሱ የሚገባቸው የሉም',
      noOverdue: 'ጊዜ ያለፈባቸው የሉም',
      noOutstanding: 'ያልተከፈሉ ሂሳቦች የሉም',
      dueBackToday: 'ዛሬ ሊመለስ ይገባዋል',
      pickedUp: 'ተወስዷል',
      overdueReturn: 'ጊዜ ያለፈ ተመላሽ',
      dayOverdue: 'ቀን ዘግይቷል', daysOverdue: 'ቀናት ዘግይቷል',
      wasDue: 'ሊመለስ ይገባ ነበር',
      totalOutstanding: 'አጠቃላይ ያልተከፈለ', remaining: 'ቀሪ',
    ),
    customers: CustomersStrings(
      title: 'ደንበኞች', totalCustomers: 'ጠቅላላ',
      searchHint: 'በስልክ ወይም በስም ፈልግ…',
      noCustomers: 'ምንም ደንበኞች አልተገኙም',
      tryDifferent: 'ሌላ ፍለጋ ይሞክሩ',
      active: 'ንቁ', blacklisted: 'ጥቁር ዝርዝር',
      memberSince: 'አባል ከ', lastBooking: 'የመጨረሻ ማስያዝ',
      totalBookings: 'ጠቅላላ የተያዙ', totalSpent: 'ጠቅላላ ዋጋ',
      totalPaid: 'ጠቅላላ ተከፍሏል', outstanding: 'ቀሪ ሂሳብ',
      bookingHistory: 'የማስያዝ ታሪክ',
      blacklistCustomer: 'ወደ ጥቁር ዝርዝር ጨምር',
      blacklistReason: 'ምክንያት (አስፈላጊ ካልሆነ)',
      removeBlacklist: 'ከጥቁር ዝርዝር አስወግድ',
      deleteCustomer: 'ደንበኛ ሰርዝ',
      deleteWarning: 'የማስያዝ ታሪክ ይቀመጣል። ይህ ሊቀለበስ አይችልም።',
      customerInfo: 'የደንበኛ መረጃ',
      stats: 'ስታቲስቲክስ', info: 'መረጃ',
      confirmBlacklist: 'ደንበኛውን ወደ ጥቁር ዝርዝር ይጨምሩ?',
      confirmRemove: 'ከጥቁር ዝርዝር ያስወጡ?',
      confirmDelete: 'ደንበኛ ይሰረዝ?',
      blacklistWarning: 'ደንበኛው በሁሉም ወደፊት ቦኪንጎች ይታያሉ።',
      noBookings: 'ምንም ማስያዝ የለም',
      editCustomer: 'ደንበኛ ያስተካክሉ',
      since: 'ከ',
      paidLabel: 'ተከፍሏል', dueLabel: 'አልተከፈለም',
      blacklistedCustomer: 'ጥቁር ዝርዝር ደንበኛ',
      cannotBeUndone: 'ይህ ተግባር ሊቀለበስ አይችልም።',
      failedToSave: 'ለማስቀመጥ አልተቻለም። እንደገና ሞክር።',
      failedToDelete: 'ለመሰረዝ አልተቻለም። እንደገና ሞክር።',
    ),
    items: ItemsStrings(
      title: 'እቃዎች', addItem: 'እቃ ጨምር',
      code: 'ኮድ', category: 'ምድብ',
      available: 'ይገኛል', unavailable: 'አይገኝም',
      noItems: 'ምንም እቃዎች አልተገኙም',
      searchByCode: 'በኮድ ወይም ስም ፈልግ…',
      qty: 'ብዛት', minPrice: 'ዝቅተኛ ዋጋ',
      filterAll: 'ሁሉም', filterAvailable: 'ነጻ',
      filterBooked: 'የተያዙ', filterCleaning: 'በጽዳት ላይ',
      noMatch: 'ምንም እቃ አልተገኘም',
      totalUnits: 'ጠቅላላ ክፍሎች',
      inInventory: 'በዝርዝር',
      unit: 'ብዛት', units: 'ብዛቶች',
      noItemsYet: 'ምንም እቃዎች አልተጨመሩም', tapToAddItem: '+ ቢጫኑ እቃ ይጨምሩ',
      deleteItem: 'እቃ ሰርዝ', perDay: 'በቀን', editItem: 'እቃ ያስተካክሉ',
      itemName: 'የእቃ ስም', uniqueCode: 'ልዩ ኮድ', minPriceDay: 'ዝቅተኛ ዋጋ/ቀን',
      quantity: 'ብዛት', categoryOptional: 'ምድብ (አስፈላጊ ካልሆነ)', noCategory: 'ምንም ምድብ',
      descriptionOptional: 'መግለጫ (አስፈላጊ ካልሆነ)', cleaningGap: 'የጽዳት ቦታ',
      cleaningGapSub: 'ለጽዳት በቦኪንጎች መካከል አንድ ቀን',
      nameCodePriceRequired: 'ስም፣ ኮድ እና ዋጋ ያስፈልጋሉ', saveChanges: 'ለውጦች አስቀምጥ',
      addCategory: 'ምድብ ጨምር', noCategoriesYet: 'ምንም ምድቦች አልተጨመሩም',
      tapToAddCategory: '+ ቢጫኑ ምድብ ይጨምሩ', deleteCategory: 'ምድብ ሰርዝ',
      editCategory: 'ምድብ ያስተካክሉ', newCategory: 'አዲስ ምድብ',
      categoryName: 'የምድብ ስም', nameRequired: 'ስም ያስፈልጋል',
      createCategory: 'ምድብ ፍጠር',
    ),
    settings: SettingsStrings(
      title: 'ቅንብሮች',
      appSettings: 'የመተግበሪያ ቅንብሮች',
      manage: 'አስተዳደር',
      reportsSection: 'ሪፖርቶች',
      account: 'መለያ',
      serverUrl: 'የሰርቨር አድራሻ', serverUrlSub: 'የ API ሰርቨር አድራሻ',
      items: 'እቃዎች', itemsSub: 'የኪራይ ዝርዝርዎን ያስተዳድሩ',
      categories: 'ምድቦች', categoriesSub: 'የዕቃ ምድቦችን ያስተዳድሩ',
      staff: 'ሰራተኞች', staffSub: 'የሰራተኛ መለያዎችን ያስተዳድሩ',
      branches: 'ቅርንጫፎች', branchesSub: 'የሱቅ ቅርንጫፎችን ያስተዳድሩ',
      reports: 'ሪፖርቶች', reportsSub: 'ገቢ፣ ያልተከፈሉ ሂሳቦች እና ትንታኔ',
      payments: 'የክፍያ ታሪክ', paymentsSub: 'ሙሉ የፋይናንስ ምዝግብ',
      deposits: 'የዋስትና ተቀማጭ', depositsSub: 'ተቀማጭ እና ጉዳት ክትትል',
      signOut: 'ውጣ', signOutSub: 'ከመለያዎ ይውጡ',
      signOutConfirm: 'ውጣ', signOutMessage: 'መውጣት ይፈልጋሉ?',
      language: 'Language / ቋንቋ',
      languageEn: 'English — Gregorian calendar',
      languageAm: 'አማርኛ — ኢትዮጵያ ቀን',
      activeBranch: 'ንቁ ቅርንጫፍ',
      addStaff: 'ሰራተኛ ጨምር', noStaffYet: 'ምንም ሰራተኞች አልተጨመሩም',
      tapToAddStaff: '+ ቢጫኑ ሰራተኛ ይጨምሩ',
      addStaffMember: 'ሰራተኛ ጨምር',
      addStaffSubtitle: 'አዲስ የቅርንጫፍ ሥራ አስኪያጅ ወይም ሰራተኛ መለያ ይፍጠሩ',
      banned: 'ታግዷል', ban: 'ከልክል', unban: 'ፍቀድ', staffRoleLabel: 'ሚና',
      staffRequired: 'ያስፈልጋል', validEmailRequired: 'ትክክለኛ ኢሜይል ያስፈልጋል',
      minSixChars: 'ቢያንስ 6 ፊደሎች', selectBranch: 'ቅርንጫፍ ይምረጡ',
      createAccount: 'መለያ ፍጠር', pleaseSelectBranch: 'ቅርንጫፍ ይምረጡ',
      bannedMsg: 'ታግዷል', unbannedMsg: 'ፈቅዷል',
      switchBranch: 'ቅርንጫፍ ቀይር', noBranchesAvailable: 'ምንም ቅርንጫፍ የለም',
      addBranch: 'ቅርንጫፍ ጨምር', noBranchesYet: 'ምንም ቅርንጫፎች አልተጨመሩም',
      tapToAddBranch: '+ ቢጫኑ ቅርንጫፍ ይጨምሩ',
      noAddressPhone: 'አድራሻ ወይም ስልክ አልተጨመረም',
      editBranch: 'ቅርንጫፍ አስተካክል', newBranch: 'አዲስ ቅርንጫፍ',
      branchNameLabel: 'የቅርንጫፍ ስም *', addressOptional: 'አድራሻ (አስፈላጊ ካልሆነ)',
      phoneOptional: 'ስልክ (አስፈላጊ ካልሆነ)', createBranch: 'ቅርንጫፍ ፍጠር',
      branchNameRequired: 'ስም ያስፈልጋል',
    ),
    auth: AuthStrings(
      signIn: 'ግባ', email: 'ኢሜይል አድራሻ', password: 'ፓስዎርድ',
      serverUrl: 'የሰርቨር አድራሻ (ምሳሌ: http://192.168.1.1:8080)',
      configureServer: 'ሰርቨር አድራሻ አዘጋጅ',
      hideServer: 'ሰርቨር ቅንብሮች ደብቅ',
      invalidCredentials: 'ኢሜይል ወይም ፓስዎርድ ትክክል አይደለም',
      subtitle: 'የኪራይ አስተዳደር',
    ),
    modify: ModifyStrings(
      title: 'ማስያዝ ቀይር',
      stepItems: 'እቃዎች እና ቀናት', stepPayment: 'ክፍያ', stepReview: 'ማጠቃለያ',
      saveChanges: 'ለውጦች አስቀምጥ', cancel: 'ሰርዝ',
      conflictsTitle: 'ቅሬታ አለ',
      conflictsMsg: 'አንዳንድ እቃዎች በተቀየሩ ቀናት አይገኙም።',
      resolveFirst: 'መጀመሪያ ቅሬታዎቹን ያስተካክሉ',
      noItems: 'ቢያንስ አንድ እቃ ይጨምሩ',
      fetchError: 'እቃዎቹን መጫን አልተቻለም። ለማሞከር ይጫኑ።',
      notes: 'ማስታወሻዎች (አስፈላጊ ካልሆነ)', notesHint: 'ስለዚህ ለውጥ ማስታወሻ…',
      additionalPayment: 'ተጨማሪ ክፍያ',
      additionalPaymentHint: 'ለዚህ ለውጥ የተሰበሰበ ክፍያ (ካልተሰበሰበ 0)',
      pickup: 'መውሰጃ', returnDate: 'መመለሻ', days: 'ቀናት',
      searchItems: 'እቃዎች ፈልግ…',
      filterAll: 'ሁሉም',
      onlyNAvailable: 'ብቻ {n} ይገኛል',
      booked: 'ተያዟል',
      summaryTitle: 'ለውጦችን ይገምግሙ',
      noChanges: 'ምንም ለውጦች አልተገኙም',
      itemsChanged: 'እቃዎች ተቀይረዋል',
      datesChanged: 'ቀናት ተቀይረዋል',
      paymentNote: 'ለዚህ ለውጥ የተሰበሰበ ክፍያ',
    ),
    reports: ReportsStrings(
      title: 'ሪፖርቶች',
      outstanding: 'ያልተከፈሉ', daily: 'ዕለታዊ', monthly: 'ወርሃዊ',
      byItem: 'በእቃ',
      noData: 'ለዚህ ጊዜ ምንም መረጃ የለም',
      selectDate: 'ቀን ይምረጡ እና ተመልከት ይጫኑ',
      selectMonth: 'ዓመት እና ወር ይምረጡ፣ ከዚያ ተመልከት ይጫኑ',
      year: 'ዓመት', month: 'ወር', view: 'ተመልከት',
      invoice: 'ደረሰኝ', customer: 'ደንበኛ', phone: 'ስልክ',
      bookingDate: 'የተያዘበት ቀን', totalPrice: 'ጠቅላላ ዋጋ',
      totalPaid: 'ጠቅላላ ተከፍሏል', balanceDue: 'ቀሪ ሂሳብ',
      totalBookings: 'ጠቅላላ ማስያዝ', totalRevenue: 'ጠቅላላ ገቢ',
      tabOverview: 'አጠቃላይ', tabRevenue: 'ገቢ', tabReceivables: 'ሊሰበሰቡ ያሉ',
      tabItems: 'እቃዎች', tabBranches: 'ቅርንጫፎች',
      totalRevenueStat: 'ጠቅላላ ገቢ', collected: 'ተሰብስቧል',
      bookingsStat: 'ቦኪንጎች', last12Months: 'ያለፉ 12 ወራት',
      topItemsByRevenue: 'ከፍተኛ ገቢ ያላቸው እቃዎች',
      today: 'ዛሬ', thisMonth: 'ይህ ወር', custom: 'ብጁ', load: 'ጫን',
      collectionRate: 'የመሰብሰቢያ መጠን', selectPeriod: 'ጊዜ ምርጥ ለመጫን።',
      allOutstanding: 'ሁሉም ያልተከፈሉ', clearFilter: 'ማጣሪያ አጽዳ',
      noOutstandingBookings: 'ምንም ያልተከፈሉ ቦኪንጎች',
      utilization: 'አጠቃቀም', lastMonth: 'ያለፈ ወር',
      totalAllBranches: 'ጠቅላላ (ሁሉም ቅርንጫፎች)',
      selectPeriodLoad: 'ጊዜ ምርጥ እና ጫን ይጫኑ።',
      tryAgain: 'እንደገና ሞክር',
    ),
    deposits: DepositsStrings(
      title: 'የዋስትና ተቀማጭ',
      held: 'የተቀመጠ', returned: 'ተመልሷል', deducted: 'ተቀንሷል',
      noDeposits: 'ምንም ተቀማጭ አልተገኘም',
      deposit: 'ተቀማጭ', deduction: 'ቅናሽ',
      excessCharge: 'ተጨማሪ ክፍያ',
      all: 'ሁሉም', partialKeep: 'በከፊል የቀረ', fullKeep: 'የማይመለስ',
      extraDamage: 'ተጨማሪ ጉዳት',
      currentlyHeld: 'አሁን የተቀመጠ', returnedClean: 'ጽዱ ሆኖ ተመልሷል',
      keptForDamage: 'ለጉዳት ቀርቷል',
      applyFilters: 'ማጣሪያ ተግብር', fromDate: 'ከቀን', toDate: 'እስከ ቀን',
      allBranches: 'ሁሉም ቅርንጫፎች', clear: 'አጽዳ',
      noDepositRecords: 'ምንም ተቀማጭ መዝገቦች',
      tryAdjusting: 'ማጣሪያዎን ይቀይሩ',
      keptLabel: 'ቀርቷል', depositLifecycle: 'የተቀማጭ ሕይወት',
      openBooking: 'ቦኪንግ ክፈት', tryAgain: 'እንደገና ሞክር',
      statusPartialKeep: 'በከፊል የቀረ', statusFullKeep: 'የማይመለስ',
      statusExcessDamage: 'ከመጠን ያለፈ ጉዳት',
      depositCollected: 'ተቀማጭ ተሰብስቧል', awaitingReturn: 'መመለስ ይጠበቃል',
      itemReturned: 'እቃ ተመልሷል', returnedOn: 'ተመልሷል፦',
      returnDateNotRecorded: 'የመመለሻ ቀን አልተመዘገበም',
      fullDepositReturned: 'ሙሉ ተቀማጭ ተመልሷል', remainderReturned: 'የቀረው ተመልሷል',
      fullDepositKept: 'ሙሉ ተቀማጭ ቀርቷል', extraDamageCollected: 'ተጨማሪ ጉዳት ተሰብስቧል',
    ),
    payments: PaymentsStrings(
      title: 'የክፍያ ታሪክ',
      noPayments: 'ምንም ክፍያዎች አልተገኙም',
      advance: 'ቅድሚያ', additional: 'ተጨማሪ',
      securityDeposit: 'የዋስትና ተቀማጭ', refund: 'ተመላሽ',
      recordedBy: 'የተመዘገበው',
      subtitle: 'ሙሉ የፋይናንስ ምዝግብ',
      totalReceived: 'ጠቅላላ የተቀበለ', totalReturned: 'ጠቅላላ ተመላሽ',
      netCash: 'ተጣራ ጥሬ ገንዘብ',
      searchHint: 'ፈልግ…', clearAll: 'ሁሉንም አጽዳ',
      hideFilters: 'ማጣሪያ ደብቅ', showFilters: 'ማጣሪያ አሳይ',
      all: 'ሁሉም', noRecords: 'ምንም ክፍያ መዝገቦች',
      tryAdjusting: 'ማጣሪያዎን ይቀይሩ',
      paymentsWillAppear: 'ክፍያዎች ይታያሉ',
      tryAgain: 'እንደገና ሞክር', loadMore: 'ተጨማሪ ጫን', ofLabel: 'ከ',
      damage: 'ጉዳት', depositRefund: 'ተቀማጭ ተመላሽ', damageCharge: 'የጉዳት ክፍያ',
      initialAdvance: 'ቅድሚያ ክፍያ', additionalPayment: 'ተጨማሪ ክፍያ',
      depositReturned: 'ተቀማጭ ተመልሷል', depositKept: 'ተቀማጭ ቀርቷል',
      records: 'መዝገቦች', searchHintFull: 'ሂሳብ፣ ደንበኛ፣ ስልክ ፈልግ…',
      fromDate: 'ከቀን', toDate: 'እስከ ቀን',
      searchPrefix: 'ፍለጋ', fromPrefix: 'ከ', toPrefix: 'እስከ',
    ),
  );
}

// ─── Nested string classes ────────────────────────────────────────────────────

class NavStrings {
  final String bookings, newBooking, operations, customers, settings;
  final String items, categories, staff, branches, reports;
  final String logout, logoutConfirm, logoutMessage, logoutConfirmBtn;
  final String activeBranch, payments, deposits;
  const NavStrings({
    required this.bookings, required this.newBooking, required this.operations,
    required this.customers, required this.settings, required this.items,
    required this.categories, required this.staff, required this.branches,
    required this.reports, required this.logout, required this.logoutConfirm,
    required this.logoutMessage, required this.logoutConfirmBtn,
    required this.activeBranch, required this.payments, required this.deposits,
  });
}

class CommonStrings {
  final String search, clear, save, cancel, delete, edit, create, add;
  final String confirm, back, refresh, loading, noData;
  final String notes, phone, altPhone, branch, date, name, actions, status;
  final String retry, close, yes, no, tapToSelect, optional;
  const CommonStrings({
    required this.search, required this.clear, required this.save,
    required this.cancel, required this.delete, required this.edit,
    required this.create, required this.add, required this.confirm,
    required this.back, required this.refresh, required this.loading,
    required this.noData, required this.notes, required this.phone,
    required this.altPhone, required this.branch, required this.date,
    required this.name, required this.actions, required this.status,
    required this.retry, required this.close, required this.yes,
    required this.no, required this.tapToSelect, required this.optional,
  });
}

class StatusStrings {
  final String confirmed, pickedUp, returned, cancelled, active, pending;
  final String available, booked, maintenance, unavailable, cleaning;
  const StatusStrings({
    required this.confirmed, required this.pickedUp, required this.returned,
    required this.cancelled, required this.active, required this.pending,
    required this.available, required this.booked, required this.maintenance,
    required this.unavailable, required this.cleaning,
  });
  String forStatus(String s) {
    switch (s) {
      case 'CONFIRMED': return confirmed;
      case 'PICKED_UP': case 'ACTIVE': return pickedUp;
      case 'RETURNED': case 'COMPLETED': return returned;
      case 'CANCELLED': return cancelled;
      case 'PENDING': return pending;
      case 'AVAILABLE': return available;
      case 'BOOKED': return booked;
      case 'MAINTENANCE': return maintenance;
      case 'CLEANING': return cleaning;
      default: return s;
    }
  }
}

class ProfileStrings {
  final String fullName, firstName, lastName, updateName;
  final String emailAddress, newEmail, updateEmail;
  final String password, currentPassword, newPassword, confirmPassword, updatePassword;
  final String nameRequired, nameUpdated, failName;
  final String emailRequired, emailUpdated, failEmail;
  final String passRequired, passMismatch, passShort, passUpdated, failPass;
  final String roleSuperAdmin, roleShopAdmin, roleBranchManager, roleStaff;
  final String editProfile, tabName, tabEmail, tabPassword, savedSuccessfully;
  const ProfileStrings({
    required this.fullName, required this.firstName, required this.lastName,
    required this.updateName, required this.emailAddress, required this.newEmail,
    required this.updateEmail, required this.password, required this.currentPassword,
    required this.newPassword, required this.confirmPassword, required this.updatePassword,
    required this.nameRequired, required this.nameUpdated, required this.failName,
    required this.emailRequired, required this.emailUpdated, required this.failEmail,
    required this.passRequired, required this.passMismatch, required this.passShort,
    required this.passUpdated, required this.failPass,
    required this.roleSuperAdmin, required this.roleShopAdmin,
    required this.roleBranchManager, required this.roleStaff,
    required this.editProfile, required this.tabName, required this.tabEmail,
    required this.tabPassword, required this.savedSuccessfully,
  });
}

class BookingsStrings {
  final String title, allStatuses, searchHint, total, noBookings, tryDifferent;
  final String pickup, returnDate, balance, invoice;
  final String modifyBooking, editCustomerInfo, markPickedUp, markReturned;
  final String cancelBooking, recordPayment, downloadPdf;
  const BookingsStrings({
    required this.title, required this.allStatuses, required this.searchHint,
    required this.total, required this.noBookings, required this.tryDifferent,
    required this.pickup, required this.returnDate, required this.balance,
    required this.invoice, required this.modifyBooking, required this.editCustomerInfo,
    required this.markPickedUp, required this.markReturned,
    required this.cancelBooking, required this.recordPayment, required this.downloadPdf,
  });
}

class BookingDetailStrings {
  final String financialSummary, totalAgreed, totalPaid, balanceDue;
  final String securityDeposit, held, depositReturned, depositDeduction, excessCharge;
  final String customer, phone, altPhone, pickupDate, returnDate, returnedOn;
  final String notes, branch, items, changeHistory, noChanges, itemsRented, qty;
  final String markPickedUp, markReturned, cancel, pay, modify, pdf, edit;
  final String cancelledNote, advancePayments, noPayments, refundAmount;
  final String depositStatus, returned, notReturned, collected;
  final String financials, paid, balance;
  final String cancellationSummary, netKept, advancePaid, refunded, noRefundGiven;
  final String damageDeduction;
  final String rentalPeriod, duration, reason;
  final String allReturned, returnItem;
  final String depositPartial, depositKeptDamage, depositPending;
  final String paymentCollection, amountCollected, securityDepositOptional, confirmPickup;
  final String finalPayment, itemCondition, noDamage, damageFound;
  final String totalDamageAmount, describeTheDamage, completeReturn;
  final String fullRefund, noRefund, custom, customerReceives, shopKeeps;
  final String damageAssessment, noDepositCollected, damageRecorded, cancellationReason;
  final String amountToCollect, fillBalance;
  final String editBooking, paymentSection, totalAgreedPrice, totalAdvancePaid, saveChanges;
  final String rentalAgreement, includeSignatureLines, signatureLinesHint, saveToDevice, share;
  final String failedToLoad, itemMarkedReturnedMsg, paymentRecordedMsg;
  final String bookingModifiedMsg, bookingUpdatedMsg, pickedUpMsg, returnedMsg, cancelledMsg;
  final String enterValidAmountMsg, collectButton, staffFallback;
  final String collectedLog, refundedLog, enterDamageAmountMsg;
  final String unitLabel;
  const BookingDetailStrings({
    required this.financialSummary, required this.totalAgreed, required this.totalPaid,
    required this.balanceDue, required this.securityDeposit, required this.held,
    required this.depositReturned, required this.depositDeduction, required this.excessCharge,
    required this.customer, required this.phone, required this.altPhone,
    required this.pickupDate, required this.returnDate, required this.returnedOn,
    required this.notes, required this.branch, required this.items,
    required this.changeHistory, required this.noChanges, required this.itemsRented,
    required this.qty, required this.markPickedUp, required this.markReturned,
    required this.cancel, required this.pay, required this.modify, required this.pdf,
    required this.edit, required this.cancelledNote, required this.advancePayments,
    required this.noPayments, required this.refundAmount, required this.depositStatus,
    required this.returned, required this.notReturned, required this.collected,
    required this.financials, required this.paid, required this.balance,
    required this.cancellationSummary, required this.netKept, required this.advancePaid,
    required this.refunded, required this.noRefundGiven, required this.damageDeduction,
    required this.rentalPeriod, required this.duration, required this.reason,
    required this.allReturned, required this.returnItem,
    required this.depositPartial, required this.depositKeptDamage, required this.depositPending,
    required this.paymentCollection, required this.amountCollected,
    required this.securityDepositOptional, required this.confirmPickup,
    required this.finalPayment, required this.itemCondition,
    required this.noDamage, required this.damageFound,
    required this.totalDamageAmount, required this.describeTheDamage, required this.completeReturn,
    required this.fullRefund, required this.noRefund, required this.custom,
    required this.customerReceives, required this.shopKeeps,
    required this.damageAssessment, required this.noDepositCollected,
    required this.damageRecorded, required this.cancellationReason,
    required this.amountToCollect, required this.fillBalance,
    required this.editBooking, required this.paymentSection,
    required this.totalAgreedPrice, required this.totalAdvancePaid, required this.saveChanges,
    required this.rentalAgreement, required this.includeSignatureLines,
    required this.signatureLinesHint, required this.saveToDevice, required this.share,
    required this.failedToLoad, required this.itemMarkedReturnedMsg,
    required this.paymentRecordedMsg, required this.bookingModifiedMsg,
    required this.bookingUpdatedMsg, required this.pickedUpMsg,
    required this.returnedMsg, required this.cancelledMsg,
    required this.enterValidAmountMsg, required this.collectButton, required this.staffFallback,
    required this.collectedLog, required this.refundedLog, required this.enterDamageAmountMsg,
    required this.unitLabel,
  });
}

class NewBookingStrings {
  final String title, stepItems, stepPayment, stepReview, customerInfo;
  final String firstName, lastName, phone, altPhone, pickupDate, returnDate, dateNote;
  final String searchCustomer, searchItems, noItemsFound, noBranch;
  final String totalAgreed, advancePayment, securityDeposit, balanceDue;
  final String createBooking, confirmCreate, confirmTitle, successTitle, invoiceNumber, viewDetail;
  final String noItemsSelected, selectDates, next, back, selectedItems, availableItems;
  final String rentalDays, rentalDaysPlural, existingCustomer, newCustomer;
  final String noCustomerFound, saveAsNew, typeDigits, minSuggested, useMin;
  final String unitsAvail, clearOrder, order, payment, availability, saveCustomer;
  // New strings for new_booking_screen
  final String titleDates, titleItems, titleCustomer;
  final String whenIsRental, selectPickupReturn, whoIsRenting, searchByPhone;
  final String enterPhone, noItemsAvailable, expected, saveAsNewBtn, blacklisted;
  final String saveBefore, selectOrSave, enterValidTotal, advanceExceedsTotal;
  final String bookingCreated, bookingCreatedSuccess, firstNamePhoneRequired;
  final String branchLabel, dayRental, daysRental;
  final String paymentSetup, setAgreedPrice, cannotExceed, continueBtn;
  final String reviewConfirm, doubleCheck;
  final String sectionDates, sectionItems, sectionCustomer, sectionPayment;
  final String labelPickup, labelReturn, labelDuration, labelName, labelPhone, labelAltPhone;
  final String labelTotalAgreed, labelAdvance;
  final String searchItemHint, unitType, unitTypes;
  const NewBookingStrings({
    required this.title, required this.stepItems, required this.stepPayment,
    required this.stepReview, required this.customerInfo, required this.firstName,
    required this.lastName, required this.phone, required this.altPhone,
    required this.pickupDate, required this.returnDate, required this.dateNote,
    required this.searchCustomer, required this.searchItems, required this.noItemsFound,
    required this.noBranch, required this.totalAgreed, required this.advancePayment,
    required this.securityDeposit, required this.balanceDue, required this.createBooking,
    required this.confirmCreate, required this.confirmTitle, required this.successTitle,
    required this.invoiceNumber, required this.viewDetail, required this.noItemsSelected,
    required this.selectDates, required this.next, required this.back,
    required this.selectedItems, required this.availableItems,
    required this.rentalDays, required this.rentalDaysPlural,
    required this.existingCustomer, required this.newCustomer,
    required this.noCustomerFound, required this.saveAsNew, required this.typeDigits,
    required this.minSuggested, required this.useMin, required this.unitsAvail,
    required this.clearOrder, required this.order, required this.payment,
    required this.availability, required this.saveCustomer,
    required this.titleDates, required this.titleItems, required this.titleCustomer,
    required this.whenIsRental, required this.selectPickupReturn,
    required this.whoIsRenting, required this.searchByPhone,
    required this.enterPhone, required this.noItemsAvailable, required this.expected,
    required this.saveAsNewBtn, required this.blacklisted,
    required this.saveBefore, required this.selectOrSave, required this.enterValidTotal,
    required this.advanceExceedsTotal, required this.bookingCreated,
    required this.bookingCreatedSuccess, required this.firstNamePhoneRequired,
    required this.branchLabel, required this.dayRental, required this.daysRental,
    required this.paymentSetup, required this.setAgreedPrice, required this.cannotExceed,
    required this.continueBtn, required this.reviewConfirm, required this.doubleCheck,
    required this.sectionDates, required this.sectionItems, required this.sectionCustomer,
    required this.sectionPayment, required this.labelPickup, required this.labelReturn,
    required this.labelDuration, required this.labelName, required this.labelPhone,
    required this.labelAltPhone, required this.labelTotalAgreed, required this.labelAdvance,
    required this.searchItemHint, required this.unitType, required this.unitTypes,
  });
}

class OperationsStrings {
  final String title, todayPickups, dueReturns, overdue, outstanding;
  final String noPickups, noDueReturns, noOverdue, noOutstanding;
  final String dueBackToday, pickedUp, overdueReturn, dayOverdue, daysOverdue;
  final String wasDue, totalOutstanding, remaining;
  const OperationsStrings({
    required this.title, required this.todayPickups, required this.dueReturns,
    required this.overdue, required this.outstanding, required this.noPickups,
    required this.noDueReturns, required this.noOverdue, required this.noOutstanding,
    required this.dueBackToday, required this.pickedUp, required this.overdueReturn,
    required this.dayOverdue, required this.daysOverdue, required this.wasDue,
    required this.totalOutstanding, required this.remaining,
  });
}

class CustomersStrings {
  final String title, totalCustomers, searchHint, noCustomers, tryDifferent;
  final String active, blacklisted, memberSince, lastBooking;
  final String totalBookings, totalSpent, totalPaid, outstanding, bookingHistory;
  final String blacklistCustomer, blacklistReason, removeBlacklist;
  final String deleteCustomer, deleteWarning, customerInfo, stats, info;
  final String confirmBlacklist, confirmRemove, confirmDelete, blacklistWarning;
  final String noBookings, editCustomer, since;
  final String paidLabel, dueLabel, blacklistedCustomer, cannotBeUndone, failedToSave, failedToDelete;
  const CustomersStrings({
    required this.title, required this.totalCustomers, required this.searchHint,
    required this.noCustomers, required this.tryDifferent, required this.active,
    required this.blacklisted, required this.memberSince, required this.lastBooking,
    required this.totalBookings, required this.totalSpent, required this.totalPaid,
    required this.outstanding, required this.bookingHistory,
    required this.blacklistCustomer, required this.blacklistReason,
    required this.removeBlacklist, required this.deleteCustomer,
    required this.deleteWarning, required this.customerInfo, required this.stats,
    required this.info, required this.confirmBlacklist, required this.confirmRemove,
    required this.confirmDelete, required this.blacklistWarning, required this.noBookings,
    required this.editCustomer, required this.since,
    required this.paidLabel, required this.dueLabel, required this.blacklistedCustomer,
    required this.cannotBeUndone, required this.failedToSave, required this.failedToDelete,
  });
}

class ItemsStrings {
  final String title, addItem, code, category, available, unavailable, noItems;
  final String searchByCode, qty, minPrice, filterAll, filterAvailable;
  final String filterBooked, filterCleaning, noMatch, totalUnits, inInventory;
  final String unit, units;
  // Items screen management
  final String noItemsYet, tapToAddItem, deleteItem, perDay, editItem;
  final String itemName, uniqueCode, minPriceDay, quantity, categoryOptional, noCategory;
  final String descriptionOptional, cleaningGap, cleaningGapSub, nameCodePriceRequired, saveChanges;
  // Categories screen management
  final String addCategory, noCategoriesYet, tapToAddCategory, deleteCategory;
  final String editCategory, newCategory, categoryName, nameRequired, createCategory;
  const ItemsStrings({
    required this.title, required this.addItem, required this.code,
    required this.category, required this.available, required this.unavailable,
    required this.noItems, required this.searchByCode, required this.qty,
    required this.minPrice, required this.filterAll, required this.filterAvailable,
    required this.filterBooked, required this.filterCleaning, required this.noMatch,
    required this.totalUnits, required this.inInventory, required this.unit,
    required this.units,
    required this.noItemsYet, required this.tapToAddItem, required this.deleteItem,
    required this.perDay, required this.editItem, required this.itemName,
    required this.uniqueCode, required this.minPriceDay, required this.quantity,
    required this.categoryOptional, required this.noCategory,
    required this.descriptionOptional, required this.cleaningGap,
    required this.cleaningGapSub, required this.nameCodePriceRequired, required this.saveChanges,
    required this.addCategory, required this.noCategoriesYet, required this.tapToAddCategory,
    required this.deleteCategory, required this.editCategory, required this.newCategory,
    required this.categoryName, required this.nameRequired, required this.createCategory,
  });
}

class SettingsStrings {
  final String title, appSettings, manage, reportsSection, account;
  final String serverUrl, serverUrlSub, items, itemsSub, categories, categoriesSub;
  final String staff, staffSub, branches, branchesSub, reports, reportsSub;
  final String payments, paymentsSub, deposits, depositsSub;
  final String signOut, signOutSub, signOutConfirm, signOutMessage;
  final String language, languageEn, languageAm, activeBranch;
  // Staff management screen
  final String addStaff, noStaffYet, tapToAddStaff, addStaffMember, addStaffSubtitle;
  final String banned, ban, unban, staffRoleLabel;
  final String staffRequired, validEmailRequired, minSixChars;
  final String selectBranch, createAccount, pleaseSelectBranch, bannedMsg, unbannedMsg;
  // Branch management screen
  final String switchBranch, noBranchesAvailable, addBranch, noBranchesYet, tapToAddBranch;
  final String noAddressPhone, editBranch, newBranch, branchNameLabel, addressOptional;
  final String phoneOptional, createBranch, branchNameRequired;
  const SettingsStrings({
    required this.title, required this.appSettings, required this.manage,
    required this.reportsSection, required this.account, required this.serverUrl,
    required this.serverUrlSub, required this.items, required this.itemsSub,
    required this.categories, required this.categoriesSub, required this.staff,
    required this.staffSub, required this.branches, required this.branchesSub,
    required this.reports, required this.reportsSub, required this.payments,
    required this.paymentsSub, required this.deposits, required this.depositsSub,
    required this.signOut, required this.signOutSub, required this.signOutConfirm,
    required this.signOutMessage, required this.language, required this.languageEn,
    required this.languageAm, required this.activeBranch,
    required this.addStaff, required this.noStaffYet, required this.tapToAddStaff,
    required this.addStaffMember, required this.addStaffSubtitle,
    required this.banned, required this.ban, required this.unban, required this.staffRoleLabel,
    required this.staffRequired, required this.validEmailRequired, required this.minSixChars,
    required this.selectBranch, required this.createAccount,
    required this.pleaseSelectBranch, required this.bannedMsg, required this.unbannedMsg,
    required this.switchBranch, required this.noBranchesAvailable, required this.addBranch,
    required this.noBranchesYet, required this.tapToAddBranch, required this.noAddressPhone,
    required this.editBranch, required this.newBranch, required this.branchNameLabel,
    required this.addressOptional, required this.phoneOptional, required this.createBranch,
    required this.branchNameRequired,
  });
}

class AuthStrings {
  final String signIn, email, password, serverUrl, configureServer, hideServer;
  final String invalidCredentials, subtitle;
  const AuthStrings({
    required this.signIn, required this.email, required this.password,
    required this.serverUrl, required this.configureServer, required this.hideServer,
    required this.invalidCredentials, required this.subtitle,
  });
}

class ModifyStrings {
  final String title, stepItems, stepPayment, stepReview, saveChanges, cancel;
  final String conflictsTitle, conflictsMsg, resolveFirst, noItems, fetchError;
  final String notes, notesHint, additionalPayment, additionalPaymentHint;
  final String pickup, returnDate, days, searchItems, filterAll, onlyNAvailable, booked;
  final String summaryTitle, noChanges, itemsChanged, datesChanged, paymentNote;
  const ModifyStrings({
    required this.title, required this.stepItems, required this.stepPayment,
    required this.stepReview, required this.saveChanges, required this.cancel,
    required this.conflictsTitle, required this.conflictsMsg, required this.resolveFirst,
    required this.noItems, required this.fetchError, required this.notes,
    required this.notesHint, required this.additionalPayment,
    required this.additionalPaymentHint, required this.pickup, required this.returnDate,
    required this.days, required this.searchItems, required this.filterAll,
    required this.onlyNAvailable, required this.booked, required this.summaryTitle,
    required this.noChanges, required this.itemsChanged, required this.datesChanged,
    required this.paymentNote,
  });
}

class ReportsStrings {
  final String title, outstanding, daily, monthly, byItem, noData;
  final String selectDate, selectMonth, year, month, view;
  final String invoice, customer, phone, bookingDate, totalPrice;
  final String totalPaid, balanceDue, totalBookings, totalRevenue;
  // New reports screen strings
  final String tabOverview, tabRevenue, tabReceivables, tabItems, tabBranches;
  final String totalRevenueStat, collected, bookingsStat, last12Months, topItemsByRevenue;
  final String today, thisMonth, custom, load, collectionRate, selectPeriod;
  final String allOutstanding, clearFilter, noOutstandingBookings;
  final String utilization, lastMonth;
  final String totalAllBranches, selectPeriodLoad, tryAgain;
  const ReportsStrings({
    required this.title, required this.outstanding, required this.daily,
    required this.monthly, required this.byItem, required this.noData,
    required this.selectDate, required this.selectMonth, required this.year,
    required this.month, required this.view, required this.invoice,
    required this.customer, required this.phone, required this.bookingDate,
    required this.totalPrice, required this.totalPaid, required this.balanceDue,
    required this.totalBookings, required this.totalRevenue,
    required this.tabOverview, required this.tabRevenue, required this.tabReceivables,
    required this.tabItems, required this.tabBranches,
    required this.totalRevenueStat, required this.collected, required this.bookingsStat,
    required this.last12Months, required this.topItemsByRevenue,
    required this.today, required this.thisMonth, required this.custom,
    required this.load, required this.collectionRate, required this.selectPeriod,
    required this.allOutstanding, required this.clearFilter, required this.noOutstandingBookings,
    required this.utilization, required this.lastMonth,
    required this.totalAllBranches, required this.selectPeriodLoad, required this.tryAgain,
  });
}

class DepositsStrings {
  final String title, held, returned, deducted, noDeposits;
  final String deposit, deduction, excessCharge;
  // New deposits screen strings
  final String all, partialKeep, fullKeep, extraDamage;
  final String currentlyHeld, returnedClean, keptForDamage;
  final String applyFilters, fromDate, toDate, allBranches, clear;
  final String noDepositRecords, tryAdjusting, keptLabel;
  final String depositLifecycle, openBooking, tryAgain;
  final String statusPartialKeep, statusFullKeep, statusExcessDamage;
  // Timeline strings
  final String depositCollected, awaitingReturn, itemReturned, returnedOn;
  final String returnDateNotRecorded, fullDepositReturned, remainderReturned;
  final String fullDepositKept, extraDamageCollected;
  const DepositsStrings({
    required this.title, required this.held, required this.returned,
    required this.deducted, required this.noDeposits, required this.deposit,
    required this.deduction, required this.excessCharge,
    required this.all, required this.partialKeep, required this.fullKeep,
    required this.extraDamage, required this.currentlyHeld,
    required this.returnedClean, required this.keptForDamage,
    required this.applyFilters, required this.fromDate, required this.toDate,
    required this.allBranches, required this.clear,
    required this.noDepositRecords, required this.tryAdjusting, required this.keptLabel,
    required this.depositLifecycle, required this.openBooking, required this.tryAgain,
    required this.statusPartialKeep, required this.statusFullKeep, required this.statusExcessDamage,
    required this.depositCollected, required this.awaitingReturn, required this.itemReturned,
    required this.returnedOn, required this.returnDateNotRecorded, required this.fullDepositReturned,
    required this.remainderReturned, required this.fullDepositKept, required this.extraDamageCollected,
  });
}

class PaymentsStrings {
  final String title, noPayments, advance, additional, securityDeposit, refund, recordedBy;
  // New payment history screen strings
  final String subtitle, totalReceived, totalReturned, netCash;
  final String searchHint, clearAll, hideFilters, showFilters;
  final String all, noRecords, tryAdjusting, paymentsWillAppear;
  final String tryAgain, loadMore, ofLabel;
  final String damage, depositRefund, damageCharge;
  // Payment type labels
  final String initialAdvance, additionalPayment, depositReturned, depositKept;
  // Filter / list strings
  final String records, searchHintFull, fromDate, toDate;
  final String searchPrefix, fromPrefix, toPrefix;
  const PaymentsStrings({
    required this.title, required this.noPayments, required this.advance,
    required this.additional, required this.securityDeposit, required this.refund,
    required this.recordedBy,
    required this.subtitle, required this.totalReceived, required this.totalReturned,
    required this.netCash, required this.searchHint, required this.clearAll,
    required this.hideFilters, required this.showFilters,
    required this.all, required this.noRecords, required this.tryAdjusting,
    required this.paymentsWillAppear, required this.tryAgain, required this.loadMore,
    required this.ofLabel, required this.damage, required this.depositRefund,
    required this.damageCharge,
    required this.initialAdvance, required this.additionalPayment,
    required this.depositReturned, required this.depositKept,
    required this.records, required this.searchHintFull, required this.fromDate,
    required this.toDate, required this.searchPrefix, required this.fromPrefix,
    required this.toPrefix,
  });
}
