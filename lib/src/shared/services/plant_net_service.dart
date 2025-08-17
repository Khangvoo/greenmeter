
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PlantNetService {
  final String _apiKey = '2b101q769lSnJm4CUS3HCxryRO'; // User provided API key
  final String _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';

  Future<Map<String, dynamic>> identifyPlant(File imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl?api-key=$_apiKey'));
    request.files.add(await http.MultipartFile.fromPath('images', imageFile.path));
    
    // You can add organs if you know them, e.g., 'flower', 'leaf', 'bark', 'fruit'
    // request.fields['organs'] = 'flower'; 

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to identify plant: ${response.statusCode} - $responseBody');
    }
  }
}
