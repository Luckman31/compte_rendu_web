import 'dart:typed_data';
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  runApp(const CompteRenduApp());
}

class CompteRenduApp extends StatelessWidget {
  const CompteRenduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Compte Rendu',
      home: const FormulairePage(),
    );
  }
}

class FormulairePage extends StatefulWidget {
  const FormulairePage({super.key});

  @override
  State<FormulairePage> createState() => _FormulairePageState();
}

class _FormulairePageState extends State<FormulairePage> {
  // Contrôleurs pour le formulaire
  final dateController = TextEditingController();
  final typeController = TextEditingController();
  final technicienController = TextEditingController();
  final contactController = TextEditingController();
  final clientController = TextEditingController();
  final siteController = TextEditingController();
  final adresseController = TextEditingController();
  final coordonneesController = TextEditingController();
  final descriptionController = TextEditingController();

  // Photos
  List<Uint8List> photosAvant = [];
  List<Uint8List> photosApres = [];
  final picker = ImagePicker();

  // Tableau dynamique pour pièces remplacées
  List<Map<String, TextEditingController>> travaux = [];

  // Signature
  final SignatureController signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void initState() {
    super.initState();
    _ajouterTravail(); // au moins une ligne par défaut
    _loadFromUrl();     // charge le formulaire depuis l'URL si présent
  }

  // ===== Gestion des travaux =====
  void _ajouterTravail() {
    setState(() {
      travaux.add({
        'Nom': TextEditingController(),
        'Quantité': TextEditingController(),
      });
    });
  }

  void _supprimerTravail(int index) {
    setState(() {
      travaux[index]['Nom']!.dispose();
      travaux[index]['Quantité']!.dispose();
      travaux.removeAt(index);
    });
  }

  // ===== Gestion photos =====
  Future<void> choisirOuPrendrePhoto(bool avant) async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choisir dans la galerie'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() {
                      if (avant) photosAvant.add(bytes);
                      else photosApres.add(bytes);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Prendre une photo'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    final bytes = await image.readAsBytes();
                    setState(() {
                      if (avant) photosAvant.add(bytes);
                      else photosApres.add(bytes);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ===== Tableau infos =====
  Widget buildInfosTable() {
    final labels = [
      "Date d'intervention",
      "Type d'intervention",
      "Technicien",
      "Contact",
      "Client",
      "Site",
      "Adresse",
      "Coordonnées",
    ];
    final controllers = [
      dateController,
      typeController,
      technicienController,
      contactController,
      clientController,
      siteController,
      adresseController,
      coordonneesController,
    ];

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(3),
      },
      children: [
        for (int i = 0; i < 4; i++)
          TableRow(children: [
            buildLabelCell(labels[i]),
            buildInputCell(controllers[i]),
            buildLabelCell(labels[i + 4]),
            buildInputCell(controllers[i + 4]),
          ])
      ],
    );
  }

  Widget buildLabelCell(String text) {
    return Container(
      height: 60,
      color: Colors.grey.shade300,
      padding: const EdgeInsets.all(8),
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget buildInputCell(TextEditingController controller) {
    return Container(
      height: 60,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        maxLines: null,
        expands: true,
        decoration: const InputDecoration(
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget buildPhotos(String titre, List<Uint8List> photos, bool avant) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton(
          onPressed: () => choisirOuPrendrePhoto(avant),
          child: Text("📷 $titre"),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => Stack(
              children: [
                Image.memory(photos[index], height: 150),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        photos.removeAt(index);
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===== PDF =====
  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final logoBytes = await rootBundle.load('assets/images/logoAgds.jpeg');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final infos = {
      "Date d'intervention": dateController.text,
      "Type d'intervention": typeController.text,
      "Technicien": technicienController.text,
      "Contact": contactController.text,
      "Client": clientController.text,
      "Site": siteController.text,
      "Adresse": adresseController.text,
      "Coordonnées": coordonneesController.text,
    };

    final pieces = travaux
        .map((t) => {
              'Nom': t['Nom']!.text,
              'Quantité': t['Quantité']!.text,
            })
        .toList();

    Uint8List? signature;
    if (signatureController.isNotEmpty) {
      signature = await signatureController.toPngBytes();
    }

// Dans le build du PDF
    if (signature != null) {
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            "Signature du client",
            style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          pw.Image(pw.MemoryImage(signature), width: 200, height: 100),
        ],
      );
}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logoImage, width: 80),
                pw.SizedBox(width: 15),
                pw.Text(
                  "Compte rendu d'intervention",
                  style: pw.TextStyle(font: ttf, fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            // Tableau infos
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: infos.entries.map((e) {
                return pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      height: 25,
                      child: pw.Text(e.key, style: pw.TextStyle(font: ttf, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Container(
                      color: PdfColors.white,
                      padding: const pw.EdgeInsets.all(8),
                      height: 25,
                      child: pw.Text(e.value),
                    ),
                  ],
                );
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Description du problème",
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(descriptionController.text),
            pw.SizedBox(height: 20),
            // Pièces remplacées
            pw.Text("Pièces remplacées",
                style: pw.TextStyle(font: ttf, fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Nom", style: pw.TextStyle(font: ttf)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text("Quantité", style: pw.TextStyle(font: ttf)),
                    ),
                  ],
                ),
                ...pieces.map((p) => pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(p['Nom']!),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(p['Quantité']!),
                        ),
                      ],
                    )),
              ],
            ),
          ];
        },
      ),
    );

    // Sauvegarde PDF Web
    final pdfBytes = await pdf.save();
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'compte_rendu.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ===== Sauvegarde locale =====
  void _saveForm() {
    final data = {
      'date': dateController.text,
      'type': typeController.text,
      'technicien': technicienController.text,
      'contact': contactController.text,
      'client': clientController.text,
      'site': siteController.text,
      'adresse': adresseController.text,
      'coordonnees': coordonneesController.text,
      'description': descriptionController.text,
      'travaux': travaux.map((t) => {
        'Nom': t['Nom']!.text,
        'Quantité': t['Quantité']!.text,
      }).toList(),
    };
    html.window.localStorage['compte_rendu'] = jsonEncode(data);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modifications sauvegardées")));
  }

  void _loadForm() {
    final jsonStr = html.window.localStorage['compte_rendu'];
    if (jsonStr == null) return;
    final data = jsonDecode(jsonStr);
    dateController.text = data['date'] ?? '';
    typeController.text = data['type'] ?? '';
    technicienController.text = data['technicien'] ?? '';
    contactController.text = data['contact'] ?? '';
    clientController.text = data['client'] ?? '';
    siteController.text = data['site'] ?? '';
    adresseController.text = data['adresse'] ?? '';
    coordonneesController.text = data['coordonnees'] ?? '';
    descriptionController.text = data['description'] ?? '';
    travaux.clear();
    for (var t in data['travaux']) {
      final nom = TextEditingController(text: t['Nom']);
      final qte = TextEditingController(text: t['Quantité']);
      travaux.add({'Nom': nom, 'Quantité': qte});
    }
    setState(() {});
  }

  // ===== Nouvelle fonctionnalité : partage via URL =====
  void _generateLink() {
    final data = {
      'date': dateController.text,
      'type': typeController.text,
      'technicien': technicienController.text,
      'contact': contactController.text,
      'client': clientController.text,
      'site': siteController.text,
      'adresse': adresseController.text,
      'coordonnees': coordonneesController.text,
      'description': descriptionController.text,
      'travaux': travaux.map((t) => {
        'Nom': t['Nom']!.text,
        'Quantité': t['Quantité']!.text,
      }).toList(),
    };

    final jsonStr = jsonEncode(data);
    final encoded = base64Url.encode(utf8.encode(jsonStr));

    final url = '${html.window.location.origin}${html.window.location.pathname}?data=$encoded';

    html.window.navigator.clipboard!.writeText(url);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lien copié dans le presse-papier")));
  }

  void _loadFromUrl() {
    final uri = Uri.parse(html.window.location.href);
    final encoded = uri.queryParameters['data'];
    if (encoded == null) return;

    try {
      final jsonStr = utf8.decode(base64Url.decode(encoded));
      final data = jsonDecode(jsonStr);

      dateController.text = data['date'] ?? '';
      typeController.text = data['type'] ?? '';
      technicienController.text = data['technicien'] ?? '';
      contactController.text = data['contact'] ?? '';
      clientController.text = data['client'] ?? '';
      siteController.text = data['site'] ?? '';
      adresseController.text = data['adresse'] ?? '';
      coordonneesController.text = data['coordonnees'] ?? '';
      descriptionController.text = data['description'] ?? '';

      travaux.clear();
      for (var t in data['travaux']) {
        travaux.add({
          'Nom': TextEditingController(text: t['Nom']),
          'Quantité': TextEditingController(text: t['Quantité']),
        });
      }
      setState(() {});
    } catch (e) {
      print("Erreur lors du décodage de l'URL: $e");
    }
  }

  // ===== Interface =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Compte rendu d'intervention")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            buildInfosTable(),
            const SizedBox(height: 20),
            const Text("Description du problème", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Entrez la description...",
              ),
            ),
            const SizedBox(height: 20),
            const Text("Pièces remplacées", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...travaux.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, TextEditingController> travail = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: travail['Nom'],
                        decoration: const InputDecoration(
                          hintText: "Nom",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: travail['Quantité'],
                        decoration: const InputDecoration(
                          hintText: "Quantité utilisée",
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _supprimerTravail(index),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _ajouterTravail,
              icon: const Icon(Icons.add),
              label: const Text("Ajouter une pièce"),
            ),
            const SizedBox(height: 20),
            buildPhotos("Photo AVANT", photosAvant, true),
            const SizedBox(height: 16),
            buildPhotos("Photo APRÈS", photosApres, false),
            const SizedBox(height: 20),
            const Text("Signature du client", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 150,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
              child: Signature(
                controller: signatureController,
                backgroundColor: Colors.white,
              ),
            ),
            TextButton.icon(
              onPressed: () => signatureController.clear(),
              icon: const Icon(Icons.clear),
              label: const Text("Effacer la signature"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveForm, child: const Text("💾 Sauvegarder les modifications")),
            ElevatedButton(onPressed: _loadForm, child: const Text("📂 Charger les modifications")),
            ElevatedButton(onPressed: _generateLink, child: const Text("📎 Générer un lien pour partager")),
            ElevatedButton(
              onPressed: generatePdf,
              child: const Text("Générer le PDF"),
            ),
          ],
        ),
      ),
    );
  }


}