import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
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
    _ajouterTravail();
  }

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
                      if (avant) {
                        photosAvant.add(bytes);
                      } else {
                        photosApres.add(bytes);
                      }
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
                      if (avant) {
                        photosAvant.add(bytes);
                      } else {
                        photosApres.add(bytes);
                      }
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

  Future<void> generatePdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/OpenSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    // Récupérer le logo
    final logoBytes = await rootBundle.load('assets/images/logoAgds.jpeg');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    // Infos à passer au PDF
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
                  style: pw.TextStyle(font:ttf, fontSize: 22, fontWeight: pw.FontWeight.bold),
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
                      child: pw.Text(e.key, style: pw.TextStyle(font: ttf,fontWeight: pw.FontWeight.bold)),
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

            // Description
            pw.Text("Description du problème",
                style: pw.TextStyle(font: ttf,fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(descriptionController.text),
            pw.SizedBox(height: 20),

            // Pièces remplacées
            pw.Text("Pièces remplacées",
                style: pw.TextStyle(font: ttf,fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
            pw.SizedBox(height: 20),

            // Photos
            if (photosAvant.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Photos AVANT", style: pw.TextStyle(font: ttf,fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: photosAvant.map((p) => pw.Image(pw.MemoryImage(p), width: 120, height: 120, fit: pw.BoxFit.cover)).toList(),
                  ),
                ],
              ),
            pw.SizedBox(height: 20),
            if (photosApres.isNotEmpty)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Photos APRÈS", style: pw.TextStyle(font: ttf,fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: photosApres.map((p) => pw.Image(pw.MemoryImage(p), width: 120, height: 120, fit: pw.BoxFit.cover)).toList(),
                  ),
                ],
              ),
            pw.SizedBox(height: 20),

            // Signature
            if (signature != null)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Signature du client", style: pw.TextStyle(font: ttf,fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                    height: 100,
                    child: pw.Image(pw.MemoryImage(signature)),
                  ),
                ],
              ),
          ];
        },
      ),
    ); 

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/compte_rendu_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);

  // 2️⃣ Sauvegarder le PDF
    final pdfBytes = await pdf.save();
    await file.writeAsBytes(pdfBytes);

  // 3️⃣ Ouvrir le PDF
    await OpenFilex.open(file.path);

  
    }

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
              onPressed: () {
                signatureController.clear();
              },
              icon: const Icon(Icons.clear),
              label: const Text("Effacer la signature"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: generatePdf,
              child: const Text("Générer le PDF"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    dateController.dispose();
    typeController.dispose();
    technicienController.dispose();
    contactController.dispose();
    clientController.dispose();
    siteController.dispose();
    adresseController.dispose();
    coordonneesController.dispose();
    descriptionController.dispose();
    for (var t in travaux) {
      t['Nom']!.dispose();
      t['Quantité']!.dispose();
    }
    signatureController.dispose();
    super.dispose();
  }
}