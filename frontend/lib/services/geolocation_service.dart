import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';

/// Classe para gerenciar a geolocalização do usuário
class GeolocationService {
  final Location _location = Location();
  
  /// Verifica se o serviço de localização está habilitado e com permissão
  Future<bool> isLocationEnabled() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    
    // Verificar se o serviço está habilitado
    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return false;
      }
    }
    
    // Verificar se temos permissão
    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Solicita permissão de localização utilizando permission_handler
  Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Erro ao solicitar permissão de localização: $e');
      return false;
    }
  }
  
  /// Obtém a localização atual do usuário
  Future<LocationData?> getCurrentLocation() async {
    try {
      // Verificar se a localização está habilitada
      final enabled = await isLocationEnabled();
      if (!enabled) {
        return null;
      }
      
      // Definir configurações de precisão
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000, // 1 segundo
        distanceFilter: 10, // 10 metros
      );
      
      // Obter a localização atual
      return await _location.getLocation();
    } catch (e) {
      debugPrint('Erro ao obter localização: $e');
      return null;
    }
  }
  
  /// Calcula a distância entre duas coordenadas em metros
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const double earthRadius = 6371000; // Raio da Terra em metros
    
    // Converter para radianos
    final double lat1Rad = lat1 * (3.141592653589793 / 180);
    final double lat2Rad = lat2 * (3.141592653589793 / 180);
    final double lon1Rad = lon1 * (3.141592653589793 / 180);
    final double lon2Rad = lon2 * (3.141592653589793 / 180);
    
    // Diferença de latitude e longitude
    final double dLat = lat2Rad - lat1Rad;
    final double dLon = lon2Rad - lon1Rad;
    
    // Fórmula de Haversine
    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * asin(sqrt(a));
    
    // Distância em metros
    return earthRadius * c;
  }
  
  /// Verifica se a localização atual está dentro do raio permitido
  Future<bool> isWithinRadius({
    required double targetLat,
    required double targetLon,
    required double radiusMeters,
  }) async {
    try {
      final currentLocation = await getCurrentLocation();
      
      if (currentLocation == null) {
        return false;
      }
      
      final distance = calculateDistance(
        lat1: currentLocation.latitude!,
        lon1: currentLocation.longitude!,
        lat2: targetLat,
        lon2: targetLon,
      );
      
      return distance <= radiusMeters;
    } catch (e) {
      debugPrint('Erro ao verificar raio: $e');
      return false;
    }
  }
  
  /// Formata as coordenadas para exibição
  String formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
  
  // Funções matemáticas para cálculo de distância
  
  double sin(double x) {
    return _sin(x);
  }
  
  double cos(double x) {
    return _cos(x);
  }
  
  double asin(double x) {
    return _asin(x);
  }
  
  double sqrt(double x) {
    return _sqrt(x);
  }
  
  // Implementações das funções matemáticas
  double _sin(double x) {
    return math.sin(x);
  }
  
  double _cos(double x) {
    return math.cos(x);
  }
  
  double _asin(double x) {
    return math.asin(x);
  }
  
  double _sqrt(double x) {
    return math.sqrt(x);
  }
}