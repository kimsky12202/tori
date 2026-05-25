/// <reference path="../pb_data/types.d.ts" />

const seeds = [
  // ===== 세종시 (좌표 재보정) =====
  { code: "SEJONG_GOVERNMENT_COMPLEX", lat: 36.504039, lon: 127.262827 },
  { code: "SEJONG_LAKE_PARK", lat: 36.484300, lon: 127.261800 },
  { code: "SEJONG_ARBORETUM", lat: 36.496100, lon: 127.252100 },
  { code: "SEJONG_BEAR_TREE_PARK", lat: 36.582700, lon: 127.273700 },
  { code: "SEJONG_PRESIDENTIAL_ARCHIVES", lat: 36.503700, lon: 127.259600 },
];

const newSpots = [
  // ===== 인천 =====
  {
    code: "INCHEON_CHINATOWN",
    name: "인천 차이나타운",
    description: "한국 최대 규모의 차이나타운",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 37.474500,
    lon: 126.617800,
    radius_m: 300,
    sort_order: 600,
  },
  {
    code: "INCHEON_SONGDO_PARK",
    name: "송도 센트럴파크",
    description: "송도의 도심 중앙공원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 37.392500,
    lon: 126.638100,
    radius_m: 400,
    sort_order: 610,
  },
  {
    code: "INCHEON_WOLMIDO",
    name: "월미도",
    description: "인천의 대표 유원지",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 37.473000,
    lon: 126.598000,
    radius_m: 400,
    sort_order: 620,
  },

  // ===== 대전 =====
  {
    code: "DAEJEON_EXPO_PARK",
    name: "대전엑스포과학공원",
    description: "대전엑스포 93의 흔적",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.376700,
    lon: 127.391400,
    radius_m: 400,
    sort_order: 700,
  },
  {
    code: "DAEJEON_HANBAT",
    name: "한밭수목원",
    description: "도심 속 인공 수목원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.367800,
    lon: 127.390700,
    radius_m: 400,
    sort_order: 710,
  },
  {
    code: "DAEJEON_DAECHEONG_LAKE",
    name: "대청호",
    description: "대전의 대표 호수",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 36.480000,
    lon: 127.487000,
    radius_m: 600,
    sort_order: 720,
  },

  // ===== 대구 =====
  {
    code: "DAEGU_DONGSEONGRO",
    name: "동성로",
    description: "대구의 대표 번화가",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 35.870000,
    lon: 128.594000,
    radius_m: 300,
    sort_order: 800,
  },
  {
    code: "DAEGU_PALGONGSAN",
    name: "팔공산 갓바위",
    description: "소원을 들어주는 갓바위",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 35.991200,
    lon: 128.694700,
    radius_m: 500,
    sort_order: 810,
  },
  {
    code: "DAEGU_KIM_GWANG_SEOK",
    name: "김광석 다시그리기 길",
    description: "고 김광석을 추억하는 거리",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 35.860400,
    lon: 128.604700,
    radius_m: 250,
    sort_order: 820,
  },

  // ===== 광주 =====
  {
    code: "GWANGJU_MUDEUNGSAN",
    name: "무등산",
    description: "광주의 상징산",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 35.134000,
    lon: 126.988900,
    radius_m: 800,
    sort_order: 900,
  },
  {
    code: "GWANGJU_YANGLIM",
    name: "양림동 역사문화마을",
    description: "근대 건축물이 보존된 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 35.143300,
    lon: 126.913700,
    radius_m: 300,
    sort_order: 910,
  },
  {
    code: "GWANGJU_518_SQUARE",
    name: "5·18 민주광장",
    description: "5·18 민주화운동의 중심지",
    category: "landmark",
    icon: "modern",
    color: "#5B7DFA",
    lat: 35.146600,
    lon: 126.919300,
    radius_m: 200,
    sort_order: 920,
  },

  // ===== 강원도 =====
  {
    code: "GANGWON_SEORAKSAN",
    name: "설악산",
    description: "한국의 대표 명산",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 38.119500,
    lon: 128.465300,
    radius_m: 1200,
    sort_order: 1000,
  },
  {
    code: "GANGWON_GYEONGPO",
    name: "경포대",
    description: "강릉의 대표 해변",
    category: "beach",
    icon: "beach",
    color: "#2DA9D6",
    lat: 37.795200,
    lon: 128.906500,
    radius_m: 400,
    sort_order: 1010,
  },
  {
    code: "GANGWON_NAMI",
    name: "남이섬",
    description: "한류 드라마의 명소",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 37.790000,
    lon: 127.525500,
    radius_m: 500,
    sort_order: 1020,
  },
  {
    code: "GANGWON_SOKCHO_MARKET",
    name: "속초 중앙시장",
    description: "닭강정과 회로 유명한 전통 시장",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 38.207300,
    lon: 128.591500,
    radius_m: 250,
    sort_order: 1030,
  },

  // ===== 전주 =====
  {
    code: "JEONJU_HANOK_VILLAGE",
    name: "전주 한옥마을",
    description: "한옥 800여 채가 모인 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 35.815500,
    lon: 127.152800,
    radius_m: 400,
    sort_order: 1100,
  },
  {
    code: "JEONJU_PUNGNAMMUN",
    name: "풍남문",
    description: "전주성의 남문",
    category: "gate",
    icon: "gate",
    color: "#F2884B",
    lat: 35.813600,
    lon: 127.148700,
    radius_m: 150,
    sort_order: 1110,
  },

  // ===== 안동 =====
  {
    code: "ANDONG_HAHOE",
    name: "안동 하회마을",
    description: "유네스코 세계유산 전통 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 36.539400,
    lon: 128.516700,
    radius_m: 500,
    sort_order: 1200,
  },
  {
    code: "ANDONG_DOSAN",
    name: "도산서원",
    description: "퇴계 이황을 기리는 서원",
    category: "temple",
    icon: "temple",
    color: "#8E5CF7",
    lat: 36.726900,
    lon: 128.842600,
    radius_m: 300,
    sort_order: 1210,
  },

  // ===== 수원 =====
  {
    code: "SUWON_HWASEONG",
    name: "수원화성",
    description: "유네스코 세계유산 성곽",
    category: "palace",
    icon: "castle",
    color: "#8E5CF7",
    lat: 37.288100,
    lon: 127.013000,
    radius_m: 500,
    sort_order: 1300,
  },
  {
    code: "SUWON_GWANGGYO",
    name: "광교호수공원",
    description: "수원의 대형 호수공원",
    category: "park",
    icon: "park",
    color: "#1FAA8C",
    lat: 37.282500,
    lon: 127.064700,
    radius_m: 500,
    sort_order: 1310,
  },

  // ===== 여수 =====
  {
    code: "YEOSU_NIGHT",
    name: "여수 밤바다",
    description: "여수 해상 케이블카·돌산대교",
    category: "landmark",
    icon: "bridge",
    color: "#5B7DFA",
    lat: 34.741600,
    lon: 127.760200,
    radius_m: 500,
    sort_order: 1400,
  },
  {
    code: "YEOSU_HYANGIRAM",
    name: "향일암",
    description: "일출 명소 사찰",
    category: "temple",
    icon: "temple",
    color: "#8E5CF7",
    lat: 34.611500,
    lon: 127.825400,
    radius_m: 300,
    sort_order: 1410,
  },

  // ===== 통영 =====
  {
    code: "TONGYEONG_DONGPIRANG",
    name: "동피랑 벽화마을",
    description: "통영 항구 위 언덕 벽화마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 34.844900,
    lon: 128.426200,
    radius_m: 200,
    sort_order: 1500,
  },

  // ===== 부산 추가 =====
  {
    code: "BUSAN_JAGALCHI",
    name: "자갈치시장",
    description: "한국 최대 수산시장",
    category: "street",
    icon: "street",
    color: "#F2884B",
    lat: 35.096900,
    lon: 129.030500,
    radius_m: 250,
    sort_order: 1600,
  },
  {
    code: "BUSAN_TAEJONGDAE",
    name: "태종대",
    description: "해안 절벽 명승지",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 35.052800,
    lon: 129.087500,
    radius_m: 500,
    sort_order: 1610,
  },

  // ===== 제주 추가 =====
  {
    code: "JEJU_UDO",
    name: "우도",
    description: "제주 동쪽 작은 섬",
    category: "beach",
    icon: "beach",
    color: "#2DA9D6",
    lat: 33.504900,
    lon: 126.951500,
    radius_m: 800,
    sort_order: 1700,
  },
  {
    code: "JEJU_CHEONJIYEON",
    name: "천지연폭포",
    description: "서귀포의 폭포",
    category: "mountain",
    icon: "mountain",
    color: "#1FAA8C",
    lat: 33.246400,
    lon: 126.554800,
    radius_m: 200,
    sort_order: 1710,
  },
  {
    code: "JEJU_HYEOPJAE",
    name: "협재해수욕장",
    description: "에메랄드빛 제주 해변",
    category: "beach",
    icon: "beach",
    color: "#2DA9D6",
    lat: 33.394100,
    lon: 126.239700,
    radius_m: 400,
    sort_order: 1720,
  },

  // ===== 춘천 / 군산 =====
  {
    code: "CHUNCHEON_GIMYUJEONG",
    name: "김유정 문학촌",
    description: "소설가 김유정의 생가",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 37.815700,
    lon: 127.679400,
    radius_m: 200,
    sort_order: 1800,
  },
  {
    code: "GUNSAN_RAIL_VILLAGE",
    name: "경암동 철길마을",
    description: "철길을 따라 들어선 옛 마을",
    category: "village",
    icon: "village",
    color: "#F2884B",
    lat: 35.987500,
    lon: 126.717100,
    radius_m: 200,
    sort_order: 1900,
  },
];

migrate((app) => {
  const col = app.findCollectionByNameOrId("tourist_spots");

  // 1) 기존 세종 좌표 재보정
  for (const patch of seeds) {
    let record;
    try {
      record = app.findFirstRecordByData("tourist_spots", "code", patch.code);
    } catch (_) {
      continue;
    }
    if (!record) continue;
    record.set("location", { lat: patch.lat, lon: patch.lon });
    app.save(record);
  }

  // 2) 신규 도시 시드
  for (const seed of newSpots) {
    let existing = null;
    try {
      existing = app.findFirstRecordByData("tourist_spots", "code", seed.code);
    } catch (_) {
      existing = null;
    }
    if (existing) continue;

    const record = new Record(col, {
      code: seed.code,
      name: seed.name,
      description: seed.description,
      category: seed.category,
      icon: seed.icon,
      color: seed.color,
      location: { lat: seed.lat, lon: seed.lon },
      radius_m: seed.radius_m,
      is_active: true,
      sort_order: seed.sort_order,
    });
    app.save(record);
  }
}, (app) => {
  for (const seed of newSpots) {
    try {
      const record = app.findFirstRecordByData("tourist_spots", "code", seed.code);
      app.delete(record);
    } catch (_) {
      // ignore
    }
  }
});
