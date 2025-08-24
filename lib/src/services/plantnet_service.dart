import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class PlantNetService {
  final String _apiKey = '2b101q769lSnJm4CUS3HCxryRO'; // Your PlantNet API Key
  final String _baseUrl = 'https://my-api.plantnet.org/v2/identify/all';

  Future<Map<String, dynamic>> identifyPlant(File imageFile) async {
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl?api-key=$_apiKey'));
    request.files.add(await http.MultipartFile.fromPath(
      'images',
      imageFile.path,
    ));
    request.fields['organs'] = 'leaf'; // You can adjust this based on the image content

    try {
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return json.decode(responseBody);
      } else {
        print('PlantNet API Error: ${response.statusCode} - $responseBody');
        return {'error': 'Failed to identify plant: ${response.statusCode}'};
      }
    } catch (e) {
      print('PlantNet API Exception: $e');
      return {'error': 'An error occurred: $e'};
    }
  }
}