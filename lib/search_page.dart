// search_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'search_results_page.dart'; // Import the results page

class Suggestion {
  final String value;

  Suggestion({required this.value});

  factory Suggestion.fromJson(Map<String, dynamic> json) {
    return Suggestion(value: json['value']);
  }
}

// Paste the MySearchPage class and its related code here
class MySearchPage extends StatefulWidget {
  const MySearchPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MySearchPage> createState() => _MySearchPageState();
}

class _MySearchPageState extends State<MySearchPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Suggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      // Fetch and set autocomplete suggestions
      fetchSuggestions(_searchController.text).then((suggestions) {
        setState(() {
          _suggestions = suggestions;
        });
      });
    });
  }

  Future<List<Suggestion>> fetchSuggestions(String query) async {
    if (query.isEmpty) return [];
    final queryParams = {
      'v_index': 'title',
      'v_value': query,
      'library': 'all',
      'v_tablearray': 'bibliosm,serbibm,apabibibm,mmbibm,',
      'cirtype': '',
      'sortfield': 'ptitle',
      'sorttype': 'desc',
      'v_page': '1',
      'pageNum': '20',
      'v_startpubyear': '',
      'v_endpubyear': '',
      'client_id': 't1',
    };

    final queryUri = Uri.https('www.szlib.org.cn', '/api/opacservice/getAutoComplete', queryParams);

    final response = await http.get(
      queryUri,
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.szlib.org.cn/opac/',
        'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> jsonResponse = json.decode(response.body)['data'];
      var suggestions = jsonResponse.map((data) => Suggestion.fromJson(data)).toList();

      // De-duplicate suggestions
      var uniqueSuggestionsMap = { for (var s in suggestions) s.value: s };
      var uniqueSuggestions = uniqueSuggestionsMap.values.toList();

      return uniqueSuggestions;
    } else {
      throw Exception('Failed to load suggestions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: // Inside _MySearchPageState class, modify the TextField widget
                TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                suffixIcon: Icon(Icons.search),
              ),
              onSubmitted: (String query) {
                // Navigate to the results page with the search query
                if (query.isNotEmpty) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => ResultsPage(searchQuery: query),
                  ));
                }
              },
            ),
          ),
          Expanded(
            child: _searchController.text.isEmpty
                ? const Center(child: Text('Type to get suggestions'))
                : FutureBuilder<List<Suggestion>>(
              future: fetchSuggestions(_searchController.text),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Text('Fetching...'));
                } else if (snapshot.hasError) {
                  return const Center(child: Text('Error fetching results'));
                } else if (snapshot.data == null || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No Result'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final suggestion = snapshot.data![index];
                      return ListTile(
                        title: Text(suggestion.value),
                        trailing: IconButton(
                          icon: Icon(Icons.north_west),
                          onPressed: () {
                            // Fill the search box with the suggestion text without submitting
                            _searchController.text = suggestion.value;
                            // Optionally, you can also clear the suggestions or close the search suggestions dropdown here
                          },
                        ),
                        onTap: () {
                          // Fill the search box and submit the search
                          _searchController.text = suggestion.value;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => ResultsPage(searchQuery: suggestion.value),
                          ));
                        },
                      );
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
