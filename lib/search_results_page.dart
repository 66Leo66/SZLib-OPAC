import 'dart:ffi';

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:szlibopac/book_details_page.dart';

class SearchResult {
  final String publisher;
  final String author;
  final String title;
  final String publishYear;
  final String isbn;
  final String coverPath;
  final String uTitle;
  final String uPublisher;
  final String abstract;
  final String recordId;

  SearchResult({
    required this.publisher,
    required this.author,
    required this.title,
    required this.publishYear,
    required this.isbn,
    required this.coverPath,
    required this.uTitle,
    required this.uPublisher,
    required this.abstract,
    required this.recordId,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      publisher: json['publisher'] as String? ?? 'Unknown',
      author: json['author'] as String? ?? 'Unknown',
      title: json['title'] as String? ?? 'Unknown',
      publishYear: json['publishyear'] as String? ?? 'Unknown',
      isbn: json['u_isbn'] as String? ?? 'Unknown',
      coverPath: json['cover_path'] as String? ?? 'Unknown',
      uTitle: json['u_title'] as String? ?? 'Unknown',
      uPublisher: json['u_publish'] as String? ?? 'Unknown',
      abstract: json['u_abstract'] as String? ?? 'Unknown',
      recordId: (json['recordid'] as int).toString(),
    );
  }
}

Future<List<SearchResult>> fetchResults(String query) async {
  final queryParams = {
    'v_index': 'title',
    'v_value': query,
    'library': 'all',
    'v_tablearray': 'bibliosm,serbibm,apabibibm,mmbibm,',
    'cirtype': '',
    'sortfield': 'ptitle',
    'sorttype': 'desc',
    'pageNum': '10',
    'v_page': '1',
    'v_startpubyear': '',
    'v_endpubyear': '',
    'v_secondquery': '',
    'client_id': 't1',
  };

  final queryUri = Uri.https(
      'www.szlib.org.cn', '/api/opacservice/getQueryResult', queryParams);

  final response = await http.get(
    queryUri,
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
    final jsonResponse = json.decode(response.body);
    final List<dynamic> docs = jsonResponse['data']['docs'];
    return docs.map((doc) => SearchResult.fromJson(doc)).toList();
  } else {
    throw Exception('Failed to load results');
  }
}

class ResultsPage extends StatefulWidget {
  final String searchQuery;

  const ResultsPage({super.key, required this.searchQuery});

  @override
  _ResultsPageState createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Results for "${widget.searchQuery}"'),
      ),
      body: FutureBuilder<List<SearchResult>>(
        future: fetchResults(widget.searchQuery),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('No results found'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final result = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          result.coverPath,
                          width: 100,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.title,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text(result.uTitle,
                                  style: const TextStyle(fontSize: 16)),
                              Text(
                                'ISBN: ${result.isbn}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Publisher: ${result.publisher}, ${result.publishYear}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text(
                                'Author: ${result.author}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              Text('Abstract: ${result.abstract ?? "没有摘要"}'),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.of(context).push(MaterialPageRoute(builder:
                                        (context) => BookDetailsPage(recordId: result.recordId)
                                      ));
                                    },
                                    child: const Text('Details'),
                                  ),
                                  // const SizedBox(width: 10),
                                  // ElevatedButton(
                                  //   onPressed: () {
                                  //     // Handle borrow button press
                                  //   },
                                  //   child: const Text('Borrow'),
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
