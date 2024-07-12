import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BookDetailsPage extends StatefulWidget {
  final String recordId;

  const BookDetailsPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _BookDetailsPageState createState() => _BookDetailsPageState();
}

class _BookDetailsPageState extends State<BookDetailsPage> {
  late Future<Map<String, dynamic>> _bookDetailsFuture;

  @override
  void initState() {
    super.initState();
    _bookDetailsFuture = fetchBookDetails(widget.recordId);
  }

  Future<Map<String, dynamic>> fetchBookDetails(String recordId) async {
    final bookDetailParams = {
      'metaTable': 'bibliosm',
      'metaId': recordId,
      'library': 'all',
      'client_id': 't1',
    };

    final bookDetailUri = Uri.https(
        'www.szlib.org.cn', '/api/opacservice/getBookDetail', bookDetailParams);

    final response = await http.get(
      bookDetailUri,
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,zh-Hans;q=0.7',
        'Connection': 'keep-alive',
        'Referer': 'https://www.szlib.org.cn/opac/',
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Merge CanLoanBook and OnlyReadBook
      final canLoanBooks = data['CanLoanBook'] ?? [];
      final onlyReadBooks = data['OnlyReadBook'] ?? [];
      final mergedBooks = [...canLoanBooks, ...onlyReadBooks];

      // Add the merged list back to the data map under a new key
      data['MergedBooks'] = mergedBooks;
      // debugPrint(mergedBooks.toString());

      return data;
    } else {
      throw Exception('Failed to load book details');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book Details'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _bookDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          } else {
            final bookData = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Title: ${bookData['title']}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Author: ${bookData['author']}', style: TextStyle(fontSize: 18)),
                  Text('Publish: ${bookData['publish']}', style: TextStyle(fontSize: 18)),
                  Text('ISBN: ${bookData['isbn']}', style: TextStyle(fontSize: 18)),
                  Text('Subject: ${bookData['subject']}', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 16),
                  Text('Abstract:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  Text('${bookData['abstract']}', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 16),
                  Text('Available Locations:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  _buildDistrictList(bookData['districtList'] ?? []),
                  if (bookData['BorrowedBook'] != null)
                    _buildBorrowedBooks(bookData['BorrowedBook']),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildDistrictList(List<dynamic> districts) {
    return Column(
      children: districts.where((district) => !district["notes"].toString().startsWith("已借出馆藏")).map<Widget>((district) {
        return ExpansionTile(
          title: Text(district['notes'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          children: (district['InsideServiceAddr'] ?? [] as List<dynamic>).map<Widget>((library) {
            return ExpansionTile(
              title: Text(library['note'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              subtitle: Text(library['library'] ?? "无地址", style: TextStyle(fontSize: 14)),
              children: _buildBookList(library['name']),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  List<Widget> _buildBookList(String libraryName) {
    return [
      FutureBuilder<Map<String, dynamic>>(
        future: _bookDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          } else {
            final bookData = snapshot.data!;
            final books = (bookData['MergedBooks'] ?? [] as List<dynamic>)
                .where((book) => book['serviceaddr'] == libraryName)
                .expand((book) => book['recordList'] as List<dynamic>)
                .toList();
            return Column(
              children: books.map<Widget>((book) {
                return ListTile(
                  title: Text('Barcode: ${book['barcode']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Location: ${book['local']}', style: TextStyle(fontSize: 14)),
                      Text('Circulation Type: ${book['cirtype']}', style: TextStyle(fontSize: 14)),
                      Text('Call Number: ${book['callno']}', style: TextStyle(fontSize: 14)),
                      Text('Status: ${book['status']}', style: TextStyle(fontSize: 14)),
                      if (book['shelfnoDesc'] != null && book['shelfnoDesc'].isNotEmpty && book['shelfnoDesc'] != "0")
                        // Text('Shelf Location: ${book['shelfnoDesc']}', style: TextStyle(fontSize: 14)),
                        parseAndDisplayShelfLocation(book['shelfnoDesc']),
                    ],
                  ),
                );
              }).toList(),
            );
          }
        },
      ),
    ];
  }

  Widget _buildBorrowedBooks(Map<String, dynamic> borrowedBookData) {
    final borrowedBooks = borrowedBookData['recordList'] as List<dynamic>;
    return ExpansionTile(
      title: Text(borrowedBookData['notes'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      children: borrowedBooks.map<Widget>((book) {
        return ListTile(
          title: Text('Barcode: ${book['barcode']}'),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location: ${book['local']}', style: TextStyle(fontSize: 14)),
              Text('Circulation Type: ${book['cirtype']}', style: TextStyle(fontSize: 14)),
              Text('Call Number: ${book['callno']}', style: TextStyle(fontSize: 14)),
              Text('Status: ${book['status']}', style: TextStyle(fontSize: 14)),
              if (book['ReturnDate'] != null)
                Text('Return Date: ${book['ReturnDate']}', style: TextStyle(fontSize: 14)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget parseAndDisplayShelfLocation(String shelfnoDesc) {
    // Pattern to match the RGB values and the text
    final pattern = RegExp(r"RGB\((\d+),(\d+),(\d+)\).*nbsp;(.+)");
    final match = pattern.firstMatch(shelfnoDesc);

    if (match != null) {
      // Extracting RGB values and text
      final red = int.parse(match.group(1)!);
      final green = int.parse(match.group(2)!);
      final blue = int.parse(match.group(3)!);
      final text = match.group(4)!;

      // Creating the widget
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(text: 'Shelf Location: ', style: TextStyle(fontSize: 14, color: Colors.black)),
            WidgetSpan(
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(red, green, blue, 1),
                ),
              ),
            ),
            TextSpan(
              text: ' $text',
              style: TextStyle(
                color: Colors.black, // Adjust text color as needed
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    } else {
      // If the pattern does not match, display the original string
      return Text('Shelf Location: ${shelfnoDesc}', style: TextStyle(fontSize: 14));
    }
  }
}