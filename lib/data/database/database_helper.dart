import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

const String databaseName = 'invoice_app.db';
const int databaseVersion = 3;

const String tableCompany = 'company';
const String tableClient = 'client';
const String tableInvoice = 'invoice';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = await getDatabasesPath();
    String dbPath = join(path, databaseName);

    return await openDatabase(
      dbPath,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE $tableCompany ADD COLUMN logoPath TEXT');
        await db.execute('ALTER TABLE $tableCompany ADD COLUMN signaturePath TEXT');
      } catch (e) {
        // Columns already exist
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${tableClient}_new (
            id TEXT PRIMARY KEY,
            businessName TEXT NOT NULL,
            phoneNumber TEXT,
            email TEXT,
            gstNumber TEXT,
            billingAddress TEXT,
            billingCity TEXT,
            billingState TEXT,
            billingPincode TEXT,
            shippingAddress TEXT,
            shippingCity TEXT,
            shippingState TEXT,
            shippingPincode TEXT
          )
        ''');

        await db.execute('''
          INSERT OR IGNORE INTO ${tableClient}_new 
          SELECT 
            id,
            COALESCE(businessName, business_name) as businessName,
            COALESCE(phoneNumber, phone_number) as phoneNumber,
            email,
            COALESCE(gstNumber, gst_number) as gstNumber,
            COALESCE(billingAddress, billing_address) as billingAddress,
            COALESCE(billingCity, billing_city) as billingCity,
            COALESCE(billingState, billing_state) as billingState,
            COALESCE(billingPincode, billing_pincode) as billingPincode,
            COALESCE(shippingAddress, shipping_address) as shippingAddress,
            COALESCE(shippingCity, shipping_city) as shippingCity,
            COALESCE(shippingState, shipping_state) as shippingState,
            COALESCE(shippingPincode, shipping_pincode) as shippingPincode
          FROM $tableClient
        ''');

        await db.execute('DROP TABLE $tableClient');
        await db.execute('ALTER TABLE ${tableClient}_new RENAME TO $tableClient');
      } catch (e) {
        // Migration error
      }

      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS ${tableInvoice}_new (
            id TEXT PRIMARY KEY,
            companyId TEXT NOT NULL,
            clientId TEXT NOT NULL,
            invoiceNumber TEXT NOT NULL,
            invoiceDate INTEGER NOT NULL,
            dueDate INTEGER,
            subtotal REAL,
            cgstTotal REAL,
            sgstTotal REAL,
            grandTotal REAL,
            notes TEXT,
            status INTEGER NOT NULL,
            items TEXT,
            poNumber TEXT,
            poDate INTEGER
          )
        ''');

        await db.execute('''
          INSERT OR IGNORE INTO ${tableInvoice}_new 
          SELECT 
            id,
            COALESCE(companyId, company_id) as companyId,
            COALESCE(clientId, client_id) as clientId,
            COALESCE(invoiceNumber, invoice_number) as invoiceNumber,
            COALESCE(invoiceDate, invoice_date) as invoiceDate,
            COALESCE(dueDate, due_date) as dueDate,
            subtotal,
            COALESCE(cgstTotal, cgst_total) as cgstTotal,
            COALESCE(sgstTotal, sgst_total) as sgstTotal,
            COALESCE(grandTotal, grand_total) as grandTotal,
            notes,
            status,
            items,
            COALESCE(poNumber, po_number) as poNumber,
            COALESCE(poDate, po_date) as poDate
          FROM $tableInvoice
        ''');

        await db.execute('DROP TABLE $tableInvoice');
        await db.execute('ALTER TABLE ${tableInvoice}_new RENAME TO $tableInvoice');
      } catch (e) {
        // Migration error
      }
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE $tableInvoice ADD COLUMN transportMode TEXT');
        await db.execute('ALTER TABLE $tableInvoice ADD COLUMN vehicleNumber TEXT');
      } catch (e) {
        // Columns already exist
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableCompany (
        id TEXT PRIMARY KEY,
        businessName TEXT NOT NULL,
        gstNumber TEXT,
        mobileNumber TEXT,
        emailAddress TEXT,
        billingAddress TEXT,
        billingCity TEXT,
        billingState TEXT,
        billingPincode TEXT,
        bankName TEXT,
        accountNumber TEXT,
        ifscCode TEXT,
        accountHolderName TEXT,
        logoPath TEXT,
        signaturePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableClient (
        id TEXT PRIMARY KEY,
        businessName TEXT NOT NULL,
        phoneNumber TEXT,
        email TEXT,
        gstNumber TEXT,
        billingAddress TEXT,
        billingCity TEXT,
        billingState TEXT,
        billingPincode TEXT,
        shippingAddress TEXT,
        shippingCity TEXT,
        shippingState TEXT,
        shippingPincode TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableInvoice (
        id TEXT PRIMARY KEY,
        companyId TEXT NOT NULL,
        clientId TEXT NOT NULL,
        invoiceNumber TEXT NOT NULL,
        invoiceDate INTEGER NOT NULL,
        dueDate INTEGER,
        subtotal REAL,
        cgstTotal REAL,
        sgstTotal REAL,
        grandTotal REAL,
        notes TEXT,
        status INTEGER NOT NULL,
        items TEXT,
        poNumber TEXT,
        poDate INTEGER,
        transportMode TEXT,
        vehicleNumber TEXT
      )
    ''');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
