#!/usr/bin/env python3
#
#  generate-sf-symbol-names.py
#  Galpi
#
#  Created by euijjang97 on 9/1/26.
#

"""SF Symbols 이름 목록을 SFSymbolNames.swift 로 생성한다.

SF Symbols 전체 이름을 열거하는 공개 API 가 없어서, 개발 머신의 시스템 번들
(CoreGlyphs)에서 이름만 뽑아 앱에 상수로 심는다. 심볼 이미지가 아니라 이름 문자열만
가져오므로 SF Symbols 라이선스(심볼 자체의 변형·재배포 금지)와 무관하다.

거르는 것:
  1. iOS 26.0 이후에 추가된 심볼 — 배포 타깃에서 렌더되지 않는다.
  2. 사용 제한 심볼(`symbol_restrictions.strings`) — Apple 제품·서비스 지칭 전용.
  3. 언어별 변형(`...ar` · `...hi` · `...rtl` 등) — 원본 이름이 목록에 이미 있으면 뺀다.

사용법 (Xcode 가 설치된 macOS 에서):
    python3 tools/generate-sf-symbol-names.py > \\
        Galpi/Features/LinkBox/Sources/SFSymbolNames.swift

새 iOS 버전으로 배포 타깃을 올렸을 때 MAX_IOS 를 바꿔 다시 돌린다.
"""

import plistlib
import sys

CORE_GLYPHS = (
    "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/"
)

MAX_IOS = (26, 0)

# 언어별 변형 심볼에 붙는 접미사. 원본 이름이 함께 존재할 때만 변형으로 간주한다.
LANGUAGE_SUFFIXES = {
    "ar", "as", "bn", "dev", "gu", "he", "hi", "ja", "km", "kn", "ko", "lo",
    "ml", "mni", "mr", "my", "ne", "or", "pa", "rtl", "sat", "si", "ta", "te",
    "th", "ur", "zh",
}


def load(name):
    with open(CORE_GLYPHS + name, "rb") as file:
        return plistlib.load(file)


def symbol_names():
    order = load("symbol_order.plist")
    availability = load("name_availability.plist")
    restricted = set(load("symbol_restrictions.strings").keys())

    releases = availability["year_to_release"]
    years = availability["symbols"]

    def supported(name):
        version = releases.get(years.get(name, ""), {}).get("iOS")
        if not version:
            return False
        return tuple(int(part) for part in version.split(".")) <= MAX_IOS

    kept = [n for n in order if supported(n) and n not in restricted]
    existing = set(kept)

    def localized(name):
        parts = name.split(".")
        return (
            len(parts) > 1
            and parts[-1] in LANGUAGE_SUFFIXES
            and ".".join(parts[:-1]) in existing
        )

    return [name for name in kept if not localized(name)]


def main():
    names = symbol_names()
    if not names:
        sys.exit("심볼 목록이 비었습니다 — CoreGlyphs 번들 경로를 확인하세요.")

    print("//")
    print("//  SFSymbolNames.swift")
    print("//  LinkBoxPresentation")
    print("//")
    print("//  Created by euijjang97 on 9/1/26.")
    print("//")
    print()
    print("// 이 파일은 tools/generate-sf-symbol-names.py 가 만든다. 직접 고치지 말 것.")
    print(f"// iOS {MAX_IOS[0]}.{MAX_IOS[1]} 까지 쓸 수 있는 심볼 {len(names)}개.")
    print()
    print("/// 줄바꿈으로 이어붙인 SF Symbol 이름. 배열 리터럴은 컴파일이 느려서")
    print("/// 문자열 하나로 두고 `SFSymbolCatalog` 가 처음 쓸 때 쪼갠다.")
    print("let sfSymbolNameList = \"\"\"")
    for name in names:
        print(name)
    print("\"\"\"")


if __name__ == "__main__":
    main()
