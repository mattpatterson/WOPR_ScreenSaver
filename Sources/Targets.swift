import Foundation

/// Named places used as launch sites and targets (approximate 1983-era geography).
struct Place {
    let name: String
    let geo: Geo
    init(_ name: String, _ lat: Double, _ lon: Double) { self.name = name; geo = Geo(lat: lat, lon: lon) }
}

enum Side { case west, east }

enum Places {
    // MARK: Launch sites
    static let usICBM = [
        Place("MINOT AFB", 48.4, -101.3), Place("GRAND FORKS AFB", 47.9, -97.4),
        Place("MALMSTROM AFB", 47.5, -111.2), Place("WHITEMAN AFB", 38.7, -93.6),
        Place("F.E. WARREN AFB", 41.1, -104.8), Place("ELLSWORTH AFB", 44.1, -103.1),
        Place("DAVIS-MONTHAN AFB", 32.2, -110.9), Place("LITTLE ROCK AFB", 34.9, -92.1),
        Place("MCCONNELL AFB", 37.6, -97.3),
    ]
    static let usSLBM = [
        Place("SSBN NORWEGIAN SEA", 69.5, 4.0), Place("SSBN N. ATLANTIC", 56.0, -28.0),
        Place("SSBN MEDITERRANEAN", 35.0, 18.0), Place("SSBN N. PACIFIC", 46.0, -165.0),
        Place("SSBN ARCTIC", 79.0, -20.0), Place("SSBN ARABIAN SEA", 16.0, 63.0),
    ]
    static let natoIRBM = [
        Place("GREENHAM COMMON", 51.4, -1.3), Place("COMISO", 37.0, 14.6),
        Place("MUTLANGEN", 48.8, 9.8), Place("FLORENNES", 50.2, 4.6), Place("WOENSDRECHT", 51.4, 4.3),
        Place("PLATEAU D'ALBION", 44.0, 5.5),
    ]
    static let ussrICBM = [
        Place("KOZELSK", 54.0, 35.8), Place("TATISHCHEVO", 51.7, 45.6), Place("DOMBAROVSKY", 51.1, 59.8),
        Place("UZHUR", 55.3, 89.8), Place("ALEYSK", 52.5, 82.5), Place("KARTALY", 53.0, 61.0),
        Place("ZHANGIZ-TOBE", 49.2, 81.2), Place("TEYKOVO", 56.9, 40.5), Place("YOSHKAR-OLA", 56.6, 47.9),
        Place("SVOBODNY", 51.4, 128.1), Place("DROVYANAYA", 51.5, 113.0), Place("KOSTROMA", 57.8, 41.0),
        Place("PERVOMAYSK", 48.0, 30.8), Place("DERAZHNYA", 49.3, 27.4),
    ]
    static let ussrSLBM = [
        Place("SSBN BARENTS SEA", 73.0, 40.0), Place("SSBN SEA OF OKHOTSK", 53.0, 150.0),
        Place("SSBN W. ATLANTIC", 36.0, -62.0), Place("SSBN E. PACIFIC", 37.0, -138.0),
        Place("SSBN KARA SEA", 75.0, 70.0),
    ]
    static let warsawIRBM = [
        Place("POSTAVY", 55.1, 26.8), Place("LIDA", 53.9, 25.3), Place("BARNAUL", 53.3, 83.8),
        Place("DRUZHNAYA", 53.0, 103.0), Place("SMORGON", 54.5, 26.4), Place("YURYA", 59.0, 49.3),
    ]
    static let chinaICBM = [
        Place("DELINGHA", 37.4, 97.4), Place("TONGDAO", 26.2, 109.8), Place("XUANHUA", 40.6, 115.0),
        Place("LUOYANG", 34.6, 112.4),
    ]

    // MARK: Targets
    static let usTargets = [
        Place("WASHINGTON DC", 38.9, -77.0), Place("NEW YORK", 40.7, -74.0), Place("CHICAGO", 41.9, -87.6),
        Place("LOS ANGELES", 34.05, -118.2), Place("SAN FRANCISCO", 37.8, -122.4), Place("SEATTLE", 47.6, -122.3),
        Place("HOUSTON", 29.8, -95.4), Place("DALLAS", 32.8, -96.8), Place("DENVER", 39.7, -105.0),
        Place("DETROIT", 42.3, -83.0), Place("BOSTON", 42.4, -71.1), Place("PHILADELPHIA", 40.0, -75.2),
        Place("ATLANTA", 33.75, -84.4), Place("MIAMI", 25.8, -80.2), Place("ST. LOUIS", 38.6, -90.2),
        Place("MINNEAPOLIS", 45.0, -93.3), Place("OFFUTT AFB", 41.1, -95.9), Place("CHEYENNE MTN", 38.8, -104.8),
        Place("NORFOLK", 36.9, -76.3), Place("SAN DIEGO", 32.7, -117.2), Place("PITTSBURGH", 40.4, -80.0),
        Place("CLEVELAND", 41.5, -81.7), Place("PHOENIX", 33.4, -112.1), Place("SALT LAKE CITY", 40.8, -111.9),
        Place("ANCHORAGE", 61.2, -149.9), Place("KANSAS CITY", 39.1, -94.6), Place("NEW ORLEANS", 30.0, -90.1),
        Place("PORTLAND", 45.5, -122.7), Place("CHARLESTON", 32.8, -79.9), Place("KINGS BAY", 30.8, -81.5),
        Place("BANGOR", 47.7, -122.7), Place("VANDENBERG AFB", 34.7, -120.6), Place("TORONTO", 43.7, -79.4),
        Place("MONTREAL", 45.5, -73.6), Place("VANCOUVER", 49.3, -123.1), Place("THULE AB", 76.5, -68.7),
    ] + usICBM
    static let ussrTargets = [
        Place("MOSCOW", 55.75, 37.6), Place("LENINGRAD", 59.9, 30.3), Place("KIEV", 50.45, 30.5),
        Place("MINSK", 53.9, 27.6), Place("KHARKOV", 50.0, 36.2), Place("GORKY", 56.3, 44.0),
        Place("KUYBYSHEV", 53.2, 50.1), Place("SVERDLOVSK", 56.8, 60.6), Place("CHELYABINSK", 55.2, 61.4),
        Place("NOVOSIBIRSK", 55.0, 82.9), Place("OMSK", 55.0, 73.4), Place("KAZAN", 55.8, 49.1),
        Place("VOLGOGRAD", 48.7, 44.5), Place("ROSTOV", 47.2, 39.7), Place("ODESSA", 46.5, 30.7),
        Place("TASHKENT", 41.3, 69.3), Place("BAKU", 40.4, 49.9), Place("TBILISI", 41.7, 44.8),
        Place("MURMANSK", 68.97, 33.1), Place("ARKHANGELSK", 64.5, 40.5), Place("VLADIVOSTOK", 43.1, 131.9),
        Place("KHABAROVSK", 48.5, 135.1), Place("IRKUTSK", 52.3, 104.3), Place("KRASNOYARSK", 56.0, 92.9),
        Place("ALMA-ATA", 43.25, 76.9), Place("RIGA", 56.95, 24.1), Place("PETROPAVLOVSK", 53.0, 158.65),
        Place("PERM", 58.0, 56.2), Place("UFA", 54.7, 56.0), Place("SARATOV", 51.5, 46.0),
        Place("SEVEROMORSK", 69.1, 33.4), Place("PLESETSK", 62.9, 40.6), Place("SEMIPALATINSK", 50.4, 80.2),
        Place("NORILSK", 69.3, 88.2), Place("YAKUTSK", 62.0, 129.7), Place("MAGADAN", 59.6, 150.8),
    ] + ussrICBM
    static let natoTargets = [
        Place("LONDON", 51.5, -0.1), Place("PARIS", 48.85, 2.35), Place("BONN", 50.7, 7.1),
        Place("HAMBURG", 53.55, 10.0), Place("BRUSSELS", 50.85, 4.35), Place("ROME", 41.9, 12.5),
        Place("MADRID", 40.4, -3.7), Place("AMSTERDAM", 52.4, 4.9), Place("OSLO", 59.9, 10.75),
        Place("COPENHAGEN", 55.7, 12.6), Place("MUNICH", 48.1, 11.6), Place("FRANKFURT", 50.1, 8.7),
        Place("RAMSTEIN AB", 49.4, 7.6), Place("HOLY LOCH", 56.0, -4.9), Place("NAPLES", 40.85, 14.3),
        Place("ANKARA", 39.9, 32.9), Place("ISTANBUL", 41.0, 29.0), Place("ATHENS", 38.0, 23.7),
        Place("LISBON", 38.7, -9.1), Place("REYKJAVIK", 64.1, -21.9), Place("GLASGOW", 55.9, -4.25),
    ] + natoIRBM
    static let warsawTargets = [
        Place("EAST BERLIN", 52.5, 13.4), Place("WARSAW", 52.2, 21.0), Place("PRAGUE", 50.1, 14.4),
        Place("BUDAPEST", 47.5, 19.0), Place("BUCHAREST", 44.4, 26.1), Place("SOFIA", 42.7, 23.3),
        Place("LEIPZIG", 51.3, 12.4), Place("KRAKOW", 50.1, 19.9), Place("GDANSK", 54.35, 18.65),
        Place("DRESDEN", 51.05, 13.7), Place("KALININGRAD", 54.7, 20.5), Place("LVOV", 49.8, 24.0),
    ]
    static let chinaTargets = [
        Place("BEIJING", 39.9, 116.4), Place("SHANGHAI", 31.2, 121.5), Place("WUHAN", 30.6, 114.3),
        Place("CHONGQING", 29.6, 106.5), Place("LOP NUR", 41.5, 88.4), Place("SHENYANG", 41.8, 123.4),
        Place("TIANJIN", 39.1, 117.2), Place("GUANGZHOU", 23.1, 113.3), Place("XIAN", 34.3, 108.9),
        Place("HARBIN", 45.75, 126.6), Place("LANZHOU", 36.1, 103.8),
    ] + chinaICBM
    static let farEastWest = [
        Place("TOKYO", 35.7, 139.7), Place("SEOUL", 37.6, 127.0), Place("OKINAWA", 26.3, 127.8),
        Place("GUAM", 13.4, 144.8), Place("MANILA", 14.6, 121.0), Place("TAIPEI", 25.0, 121.5),
        Place("YOKOSUKA", 35.3, 139.7), Place("MISAWA AB", 40.7, 141.4), Place("CLARK AB", 15.2, 120.6),
        Place("HONG KONG", 22.3, 114.2), Place("SAPPORO", 43.1, 141.35), Place("OSAKA", 34.7, 135.5),
    ]
    static let middleEast = [
        Place("TEHRAN", 35.7, 51.4), Place("BAGHDAD", 33.3, 44.4), Place("RIYADH", 24.7, 46.7),
        Place("TEL AVIV", 32.1, 34.8), Place("DAMASCUS", 33.5, 36.3), Place("CAIRO", 30.0, 31.2),
        Place("TRIPOLI", 32.9, 13.2), Place("KUWAIT", 29.4, 47.98), Place("DHAHRAN", 26.3, 50.1),
        Place("BASRA", 30.5, 47.8), Place("ADEN", 12.8, 45.0), Place("BENGHAZI", 32.1, 20.1),
    ]
    static let southAsia = [
        Place("NEW DELHI", 28.6, 77.2), Place("BOMBAY", 19.1, 72.9), Place("KARACHI", 24.9, 67.0),
        Place("ISLAMABAD", 33.7, 73.1), Place("LAHORE", 31.55, 74.35), Place("CALCUTTA", 22.6, 88.4),
        Place("KABUL", 34.5, 69.2), Place("MADRAS", 13.1, 80.3), Place("RANGOON", 16.8, 96.2),
    ]
    static let latinAmerica = [
        Place("HAVANA", 23.1, -82.4), Place("MANAGUA", 12.1, -86.3), Place("PANAMA", 9.0, -79.5),
        Place("MEXICO CITY", 19.4, -99.1), Place("BOGOTA", 4.7, -74.1), Place("CARACAS", 10.5, -66.9),
        Place("BUENOS AIRES", -34.6, -58.4), Place("SANTIAGO", -33.45, -70.65), Place("LIMA", -12.05, -77.0),
        Place("RIO DE JANEIRO", -22.9, -43.2), Place("CIENFUEGOS", 22.15, -80.45), Place("SAN JUAN", 18.45, -66.1),
    ]
    static let africa = [
        Place("KINSHASA", -4.3, 15.3), Place("ADDIS ABABA", 9.0, 38.75), Place("LUANDA", -8.8, 13.2),
        Place("NAIROBI", -1.3, 36.8), Place("LAGOS", 6.5, 3.4), Place("PRETORIA", -25.75, 28.2),
        Place("KHARTOUM", 15.6, 32.5), Place("DAKAR", 14.7, -17.45), Place("MOGADISHU", 2.05, 45.3),
    ]
    static let oceania = [
        Place("SYDNEY", -33.9, 151.2), Place("CANBERRA", -35.3, 149.1), Place("PERTH", -31.95, 115.9),
        Place("PINE GAP", -23.8, 133.7), Place("DARWIN", -12.45, 130.85), Place("WELLINGTON", -41.3, 174.8),
        Place("NORTH WEST CAPE", -21.8, 114.2),
    ]
    static let northAtlantic = [
        Place("KEFLAVIK", 64.0, -22.6), Place("REYKJAVIK", 64.1, -21.9), Place("THULE AB", 76.5, -68.7),
        Place("SONDRESTROM", 67.0, -50.7), Place("FAROE ISLANDS", 62.0, -6.8), Place("BODO", 67.3, 14.4),
        Place("GANDER", 48.95, -54.6), Place("SCAPA FLOW", 58.9, -3.1),
    ]
}
