export interface IndianStateInfo {
  id: string;
  name: string;
  code: string;
  center: { lat: number; lng: number };
  zoom: number;
  bounds: [[number, number], [number, number]]; // [southWest, northEast]
  primaryCrops: string[];
  keyDistricts: string[];
}

export const INDIAN_STATES: IndianStateInfo[] = [
  {
    id: 'MH',
    name: 'Maharashtra',
    code: 'MH',
    center: { lat: 19.7515, lng: 75.7139 },
    zoom: 6.8,
    bounds: [[15.6, 72.6], [22.1, 80.9]],
    primaryCrops: ['Cotton', 'Soybean'],
    keyDistricts: ['Yavatmal', 'Akola', 'Nagpur', 'Aurangabad', 'Nashik', 'Amravati'],
  },
  {
    id: 'PB',
    name: 'Punjab',
    code: 'PB',
    center: { lat: 31.1471, lng: 75.3412 },
    zoom: 7.5,
    bounds: [[29.5, 73.8], [32.5, 76.9]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Bathinda', 'Ludhiana', 'Mansa', 'Patiala', 'Amritsar', 'Sangrur'],
  },
  {
    id: 'GJ',
    name: 'Gujarat',
    code: 'GJ',
    center: { lat: 22.2587, lng: 71.1924 },
    zoom: 6.8,
    bounds: [[20.1, 68.1], [24.7, 74.5]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Rajkot', 'Junagadh', 'Amreli', 'Surat', 'Bhavnagar', 'Banaskantha'],
  },
  {
    id: 'KA',
    name: 'Karnataka',
    code: 'KA',
    center: { lat: 15.3173, lng: 75.7139 },
    zoom: 6.7,
    bounds: [[11.5, 74.0], [18.5, 78.6]],
    primaryCrops: ['Cotton', 'Soybean'],
    keyDistricts: ['Belagavi', 'Raichur', 'Dharwad', 'Kolar', 'Mysuru', 'Haveri'],
  },
  {
    id: 'MP',
    name: 'Madhya Pradesh',
    code: 'MP',
    center: { lat: 22.9734, lng: 78.6569 },
    zoom: 6.4,
    bounds: [[21.0, 74.0], [26.9, 82.8]],
    primaryCrops: ['Soybean'],
    keyDistricts: ['Indore', 'Ujjain', 'Bhopal', 'Hoshangabad', 'Jabalpur', 'Dewas'],
  },
  {
    id: 'UP',
    name: 'Uttar Pradesh',
    code: 'UP',
    center: { lat: 26.8467, lng: 80.9462 },
    zoom: 6.5,
    bounds: [[23.8, 77.0], [30.4, 84.6]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Meerut', 'Muzaffarnagar', 'Agra', 'Varanasi', 'Bareilly', 'Lucknow'],
  },
  {
    id: 'AP',
    name: 'Andhra Pradesh',
    code: 'AP',
    center: { lat: 15.9129, lng: 79.7400 },
    zoom: 6.8,
    bounds: [[12.6, 76.7], [19.1, 84.8]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Guntur', 'Kurnool', 'Krishna', 'Anantapur', 'East Godavari'],
  },
  {
    id: 'TS',
    name: 'Telangana',
    code: 'TS',
    center: { lat: 18.1124, lng: 79.0193 },
    zoom: 7.0,
    bounds: [[15.8, 77.2], [19.9, 81.3]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Warangal', 'Nalgonda', 'Khammam', 'Karimnagar', 'Mahabubnagar'],
  },
  {
    id: 'TN',
    name: 'Tamil Nadu',
    code: 'TN',
    center: { lat: 11.1271, lng: 78.6569 },
    zoom: 6.9,
    bounds: [[8.0, 76.2], [13.6, 80.4]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Thanjavur', 'Coimbatore', 'Madurai', 'Erode', 'Tiruchirappalli'],
  },
  {
    id: 'WB',
    name: 'West Bengal',
    code: 'WB',
    center: { lat: 22.9868, lng: 87.8550 },
    zoom: 6.8,
    bounds: [[21.5, 85.8], [27.3, 89.9]],
    primaryCrops: [],
    keyDistricts: ['Burdwan', 'Nadia', 'Hooghly', 'Murshidabad', 'North 24 Parganas'],
  },
  {
    id: 'RJ',
    name: 'Rajasthan',
    code: 'RJ',
    center: { lat: 27.0238, lng: 74.2179 },
    zoom: 6.2,
    bounds: [[23.0, 69.5], [30.2, 78.3]],
    primaryCrops: ['Cotton', 'Soybean'],
    keyDistricts: ['Sri Ganganagar', 'Kota', 'Hanumangarh', 'Jaipur', 'Alwar', 'Barmer'],
  },
  {
    id: 'HR',
    name: 'Haryana & Delhi',
    code: 'HR',
    center: { lat: 29.0588, lng: 76.0856 },
    zoom: 7.5,
    bounds: [[27.6, 74.4], [30.9, 77.6]],
    primaryCrops: ['Cotton'],
    keyDistricts: ['Hisar', 'Sirsa', 'Karnal', 'Kurukshetra', 'Sonipat', 'Delhi NCR'],
  },
  {
    id: 'BR',
    name: 'Bihar',
    code: 'BR',
    center: { lat: 25.0961, lng: 85.3131 },
    zoom: 7.0,
    bounds: [[24.2, 83.3], [27.5, 88.3]],
    primaryCrops: [],
    keyDistricts: ['Muzaffarpur', 'Patna', 'Samastipur', 'Gaya', 'Bhagalpur'],
  },
  {
    id: 'OR',
    name: 'Odisha',
    code: 'OR',
    center: { lat: 20.9517, lng: 85.0985 },
    zoom: 6.8,
    bounds: [[17.8, 81.4], [22.6, 87.5]],
    primaryCrops: [],
    keyDistricts: ['Bargarh', 'Cuttack', 'Sambalpur', 'Ganjam', 'Balasore'],
  },
  {
    id: 'KL',
    name: 'Kerala',
    code: 'KL',
    center: { lat: 10.8505, lng: 76.2711 },
    zoom: 7.2,
    bounds: [[8.3, 74.8], [12.8, 77.4]],
    primaryCrops: [],
    keyDistricts: ['Palakkad', 'Wayanad', 'Idukki', 'Alappuzha', 'Kottayam'],
  },
  {
    id: 'AS',
    name: 'Assam',
    code: 'AS',
    center: { lat: 26.2006, lng: 92.9376 },
    zoom: 7.0,
    bounds: [[24.1, 89.7], [28.0, 96.0]],
    primaryCrops: [],
    keyDistricts: ['Jorhat', 'Dibrugarh', 'Nagaon', 'Sonitpur', 'Kamrup'],
  },
];

/**
 * Maps any latitude and longitude to the most matching Indian State
 */
export function resolveIndianState(lat: number, lng: number): IndianStateInfo {
  // Check bounds first
  for (const state of INDIAN_STATES) {
    const [[minLat, minLng], [maxLat, maxLng]] = state.bounds;
    if (lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng) {
      return state;
    }
  }

  // Fallback to nearest center distance
  let nearestState = INDIAN_STATES[0];
  let minDistance = Number.MAX_VALUE;

  for (const state of INDIAN_STATES) {
    const dLat = state.center.lat - lat;
    const dLng = state.center.lng - lng;
    const distSq = dLat * dLat + dLng * dLng;
    if (distSq < minDistance) {
      minDistance = distSq;
      nearestState = state;
    }
  }

  return nearestState;
}
