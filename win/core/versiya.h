// Ilova versiyasi va ishga tushish muhiti (log va «Haqida» qatori uchun).
//
// Ilgari bu funksiyalar `statistika.cpp` da edi; Voxly'da statistika va
// avto-yangilanish olib tashlandi, versiya esa sozlamalar oynasida va logda
// koʻrinishda davom etadi.
#pragma once

#include <string>

namespace rubai {

// Ilova versiyasi, qoʻshimchasi bilan (`1.2.0-sinov1`) — `VERSION` faylidan
// kompilyatsiya vaqtida (`kotib_versiya.h`).
std::wstring joriyVersiya();

// Logdagi ishga tushish qatori uchun: «Voxly 1.2.0 x64, Windows 11 26100»
// (barqarorlik A6).
std::wstring ishgaTushishMuhiti();

}  // namespace rubai
