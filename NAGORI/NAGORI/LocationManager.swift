//
//  LocationManager.swift
//  NAGORI
//
//  Created by 髙橋潤 on 2026/09/19.
//

import Foundation
import CoreLocation
import Combine

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var rawLocation: CLLocationCoordinate2D?
    @Published var roundedLocation: CLLocationCoordinate2D?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    /// 位置情報の利用許可をリクエスト
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// 一度だけ現在地を取得
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let rawCoord = location.coordinate
        
        DispatchQueue.main.async {
            self.rawLocation = rawCoord
            // M-05: プライバシー保護のため、小数点以下3桁に丸める
            self.roundedLocation = self.roundCoordinate(rawCoord, decimals: 3)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報の取得に失敗しました: \(error.localizedDescription)")
    }
    
    // MARK: - M-05: 座標の丸め処理
    
    /// 座標の小数点以下を指定桁数で四捨五入する
    private func roundCoordinate(_ coordinate: CLLocationCoordinate2D, decimals: Int) -> CLLocationCoordinate2D {
        let multiplier = pow(10.0, Double(decimals))
        let roundedLat = (coordinate.latitude * multiplier).rounded() / multiplier
        let roundedLon = (coordinate.longitude * multiplier).rounded() / multiplier
        return CLLocationCoordinate2D(latitude: roundedLat, longitude: roundedLon)
    }
}
