import 'dart:convert';
import 'dart:io';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

void main() async {
  // --- 1. MongoDB Connection Setup ---
  final db = Db(
    'mongodb://TestUser:test7890@'
    'ac-4jeee2f-shard-00-02.f7ubkzg.mongodb.net:27017,'
    'ac-4jeee2f-shard-00-00.f7ubkzg.mongodb.net:27017,'
    'ac-4jeee2f-shard-00-01.f7ubkzg.mongodb.net:27017/Data'
    '?ssl=true&replicaSet=atlas-xotq1k-shard-0&authSource=admin&retryWrites=true&w=majority',
  );
  await db.open();

  // --- 2. Collection Setup ---
  final nightswatchCollection = db.collection("NIGHT'S WATCH");
  final starkCollection = db.collection('STARK');
  final martellCollection = db.collection('MARTELL');
  final boltonCollection = db.collection('BOLTON');
  final greyjoyCollection = db.collection('GREYJOY');
  final freeFolkCollection = db.collection('FREE FOLK');
  final lannisterCollection = db.collection('LANNISTER');
  final neutralCollection = db.collection('NEUTRAL');
  final bwbCollection = db.collection('BROTHERHOOD W/O BANNERS');
  final baratheonCollection = db.collection('BARATHEON');
  final targaryenCollection = db.collection('TARGARYEAN');
  final abilitiesCollection = db.collection('Abilities');

  final router = Router();

  // --- 3. Faction Collection Helper ---
  DbCollection? getFactionCollection(String factionName) {
    switch (factionName.toLowerCase()) {
      case 'martell':
        return martellCollection;
      case 'bolton':
        return boltonCollection;
      case 'greyjoy':
        return greyjoyCollection;
      case 'stark':
        return starkCollection;
      case "night's watch":
        return nightswatchCollection;
      case 'free folk':
        return freeFolkCollection;
      case 'lannister':
        return lannisterCollection;
      case 'targaryen':
        return targaryenCollection;
      case 'baratheon':
        return baratheonCollection;
      case 'brotherhood w/o banners':
        return bwbCollection;
      case 'neutral':
        return neutralCollection;
      default:
        return null;
    }
  }

  // --- Helper function to normalize a database document's name ---
  // This uses aggressive sanitization (removes spaces, punctuation, etc.)
  String _normalizeDocName(Map<String, dynamic> doc, RegExp sanitizer) {
    final rawName = (doc['name'] as String? ?? '').toLowerCase().trim();
    final rawTitle = (doc['title'] as String? ?? '').toLowerCase().trim();

    // The name of the unit itself (e.g., "Crannogman Trackers")
    String normalizedName = rawName
        .replaceAll(sanitizer, '')
        .replaceAll(' ', '');

    // 1. If a title exists, combine them aggressively to match the expected client string
    if (rawTitle.isNotEmpty) {
      // Combines Name + Title without any separators (e.g., 'robstarkthewolflord')
      return normalizedName +
          rawTitle.replaceAll(sanitizer, '').replaceAll(' ', '');
    }

    return normalizedName;
  }

  // --- NEW ENDPOINT: Bulk Fetch Unit Details by Name (POST) ---
  router.post('/api/units/details', (Request req) async {
    // Regex to remove anything that is NOT a letter or number (i.e., remove spaces, hyphens, parentheses, etc.)
    final RegExp sanitizer = RegExp(r'[^a-z0-9]', caseSensitive: false);

    try {
      final requestBody = await req.readAsString();
      final data = jsonDecode(requestBody) as Map<String, dynamic>;

      final factionName = data['faction'] as String?;
      final unitNames = (data['names'] as List<dynamic>?)?.cast<String>();

      if (factionName == null || unitNames == null || unitNames.isEmpty) {
        return Response.badRequest(
          body: jsonEncode({
            'error': 'Missing faction or unit names in request body',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final collection = getFactionCollection(factionName);

      if (collection == null) {
        return Response.notFound(
          jsonEncode({
            'error':
                'Faction not found or collection not mapped for: $factionName',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // --- Fetch necessary documents (omitted for brevity, assume correct) ---
      final factionDoc = await collection.findOne();
      final neutralDoc = await neutralCollection.findOne();

      DbCollection? hybridCollection1;
      DbCollection? hybridCollection2;

      if (factionName.toLowerCase() == 'brotherhood w/o banners') {
        hybridCollection1 = baratheonCollection;
        hybridCollection2 = starkCollection;
      }

      final hybridDoc1 = hybridCollection1 != null
          ? await hybridCollection1.findOne()
          : null;
      final hybridDoc2 = hybridCollection2 != null
          ? await hybridCollection2.findOne()
          : null;

      if (factionDoc == null) {
        return Response.notFound(
          jsonEncode({'error': 'Faction data document not found in MongoDB.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // --- Create a consolidated list of ALL available units/attachments/NCUs ---
      final List<Map<String, dynamic>> allAvailableDocs = [];
      // Use the singular keys here as that's how the database documents are structured
      final List<String> roleKeys = ['unit', 'ncu', 'attachment'];

      void mergeDocs(Map<String, dynamic>? doc) {
        if (doc == null) return;
        for (final key in roleKeys) {
          final docs = doc[key];
          if (docs is List) {
            allAvailableDocs.addAll(docs.cast<Map<String, dynamic>>());
          }
        }
      }

      mergeDocs(factionDoc);
      mergeDocs(neutralDoc);
      mergeDocs(hybridDoc1);
      mergeDocs(hybridDoc2);

      // --- IMPROVED MATCHING LOGIC ---
      final Map<String, Map<String, dynamic>> foundDetailsMap = {};
      final List<String> notFoundNames = [];

      // 1. Normalize the names received from the client
      final Set<String> normalizedNamesToFind = unitNames
          .map((name) => name.replaceAll(sanitizer, '').toLowerCase().trim())
          .toSet();

      // DEBUG: Print the names the server is looking for
      print(
        'DEBUG: Normalized names the server is searching for: $normalizedNamesToFind',
      );

      for (final doc in allAvailableDocs) {
        // 2. Normalize the database name using the helper
        final String docName = _normalizeDocName(doc, sanitizer);

        // Check if this document's normalized name is in the set of names to find
        if (normalizedNamesToFind.contains(docName)) {
          // Store the found document using its normalized name as the key
          if (!foundDetailsMap.containsKey(docName)) {
            foundDetailsMap[docName] = doc;
          }
        }
      }

      // Check for missing units (for the error message)
      final Set<String> foundNormalizedNames = foundDetailsMap.keys.toSet();

      for (final name in unitNames) {
        final normalizedName = name
            .replaceAll(sanitizer, '')
            .toLowerCase()
            .trim();
        if (!foundNormalizedNames.contains(normalizedName)) {
          notFoundNames.add(name);
        }
      }

      if (notFoundNames.isNotEmpty) {
        print(
          'DEBUG: Documents not found for faction: $factionName. Missing: ${notFoundNames}',
        );
        return Response.notFound(
          jsonEncode({
            'error':
                'Could not find stat details for the parsed units: ${notFoundNames.join(', ')}',
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // DEBUG: Log the successfully found units before sending
      print('DEBUG: Successfully found ${foundDetailsMap.length} units.');

      // --- FIX 4: Organize the results into the REQUIRED PLURAL JSON structure ---
      final Map<String, List<Map<String, dynamic>>> organizedResults = {
        // Use plural keys as expected by the Dart client models
        'units': [],
        'ncus': [],
        'attachments': [],
      };

      for (final doc in foundDetailsMap.values) {
        final role = (doc['role'] as String? ?? 'unknown').toLowerCase();

        // Convert the ObjectId to a String for JSON serialization (this is correct)
        if (doc['_id'] != null && doc['_id'] is ObjectId) {
          doc['_id'] = (doc['_id'] as ObjectId).toHexString();
        }

        // Route documents to the correct array based on the 'role' field
        if (role == 'ncu') {
          organizedResults['ncus']!.add(doc);
        } else if (role == 'attachment' || role == 'commander') {
          // Use 'attachments' plural key
          organizedResults['attachments']!.add(doc);
        } else {
          // Default to 'units' plural key for 'unit', 'infantry', 'cavalry', etc.
          organizedResults['units']!.add(doc);
        }
      }

      return Response.ok(
        jsonEncode(organizedResults),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('Server Error during bulk fetch: $e');
      return Response.internalServerError(
        body: jsonEncode({
          'error': 'Internal server error during fetch: ${e.toString()}',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  });

  // ... (omitting remaining routes and server setup as they are correct) ...
  router.get('/units/<faction>', (Request req, String faction) async {
    final collection = getFactionCollection(faction);
    if (collection == null) return Response.notFound('Faction not found.');
    final allDocs = await collection.find().toList();

    // Clean all IDs before encoding
    final cleanedDocs = allDocs.map((doc) {
      if (doc['_id'] != null && doc['_id'] is ObjectId) {
        doc['_id'] = (doc['_id'] as ObjectId).toHexString();
      }
      return doc;
    }).toList();

    return Response.ok(
      jsonEncode(cleanedDocs),
      headers: {'Content-Type': 'application/json'},
    );
  });

  router.get('/units/<faction>/<unitName>', (
    Request req,
    String faction,
    String unitName,
    // Note: This endpoint is likely deprecated, using the POST bulk fetch instead
  ) async {
    final collection = getFactionCollection(faction);
    if (collection == null) return Response.notFound('Faction not found.');

    final doc = await collection.findOne({
      'name': RegExp('^${RegExp.escape(unitName)}\$', caseSensitive: false),
    });

    if (doc != null) {
      doc['_id'] = doc['_id'].toHexString();
      return Response.ok(
        jsonEncode(doc),
        headers: {'Content-Type': 'application/json'},
      );
    } else {
      return Response.notFound('Unit not found: $unitName');
    }
  });

  router.get('/abilities', (Request req) async {
    final allDocs = await abilitiesCollection.find().toList();
    // Clean all IDs before encoding
    final cleanedDocs = allDocs.map((doc) {
      if (doc['_id'] != null && doc['_id'] is ObjectId) {
        doc['_id'] = (doc['_id'] as ObjectId).toHexString();
      }
      return doc;
    }).toList();

    return Response.ok(
      jsonEncode(cleanedDocs),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // --- 5. Static Portrait File Server Setup (FIXED) ---
  final portraitsHandler = createStaticHandler(
    'assets/standees',
    listDirectories: false,
    defaultDocument: null,
  );

  router.get('/portraits', portraitsHandler);

  // --- 6. CORS and Server Start ---
  Middleware handleCORS() {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
    };

    return (Handler handler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: corsHeaders);
        }

        final response = await handler(request);

        return response.change(headers: corsHeaders);
      };
    };
  }

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(handleCORS())
      .addHandler(router);

  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('✅ Server running at http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((signal) async {
    await db.close();
    print('🧹 MongoDB connection closed.');
    exit(0);
  });
}
