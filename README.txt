# vim:set tw=80:

Openmtbmap Skripte zum Herunterladen der notwendigen Dateien und erstellen der img-Dateien für Garmin GPS-Geräte

Kurzanleitung:
  - Konsole/Terminal öffnen und ins Verzeichnis wechseln, in dem die Dateien
    entpackt wurden
  - Dateien download.sh und build.rb ausführbar machen: chmod a+x download.sh
    build.rb   (im Terminal starten)
  - Datei urls.txt anpassen, damit alle notwendigen Kartendownloads enthalten
    sind. Die verfügbaren Dateien sind unter
    ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/ und
    http://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/ zu finden. Einfach
    die URLs in die Datei urls.txt kopieren. (Es sollte keinen Unterschied
    machen, ob FTP oder HTTP benutzt wird.)
  - Dateien herunterladen: ./download.sh      (im Terminal starten)
  - img-Dateien erstellen: ./build.rb *.exe   (im Terminal starten)
  - img-Dateien auf Speicherkarte des Garmin GPS kopieren, Unterverzeichnis
    Garmin/.

download.sh:

  Dateien der Openmtbmap herunterladen. Die URLs der Dateien stehen in urls.txt
  oder einer Datei, die als Parameter übergeben wird. Die Dateien werden mit
  wget heruntergeladen. Falls die Datei auf dem Server neuer ist, als die auf
  der Festplatte vorhandene Datei, wird sie neu heruntergeladen. Datum und
  Uhrzeit der Datei auf der Festplatte wird von wget so eingestellt, wie für die
  Datei auf dem Server.

  Zusätzlich wird mkgmap heruntergeladen, falls es unter
  http://www.mkgmap.org.uk/snapshots/mkgmap-latest.tar.gz eine neue Fassung
  gibt. Die Datei mkgmap.jar wird automatisch daraus entpackt und mit der
  Subversion Revisionsnummer benannt und ein symbolischer Verweis (symlink)
  mkgamp.jar -> mkgmap-XXXX.jar erstellt.

urls.txt:

  Liste der URLs, die heruntergeladen werden sollen. Typischerweise die Dateien,
  die man häufig benutzt und oft regelmäßig aktualisieren will.

build.rb:

  Erstellt aus den heruntergeladenen Karten img-Dateien für Garmin GPS-Geräte.
  Dazu wird mkgmap mit der Java Laufzeitumgebung/Runtime benötigt und benutzt.

  Die heruntergeladenen exe-Dateien werden als Parameter übergeben. Daraus
  werden img-Dateien erstellt. Die Namen der img-Dateien werden ausgehend vom
  Namen der exe-Datei, dem Dateidatum und dem Typ-Style generiert.

  Als zusätzliche Parameter können die Typ-Styles angegeben werden, mit denen
  eine img-Datei erstellt werden soll. Wenn kein Typ-Style als Parameter
  übergeben wird, wird "wide" benutzt. (Einfach, weil dieser mir an meinem
  GPS-Gerät am besten gefällt.) Die möglichen Typ-Styles sind clas, easy, hike,
  thin, trad und wide. Wenn diese "Wörter" in den Parametern vorkommen, werden
  sie als Typ-Styles betrachtet. Für jeden angegebenen Typ-Style wird eine
  img-Datei erstellt, gegebenenfalls mehrere.

  Typ-Style-Namen und exe-Dateinamen können in beliebiger Reihenfolge als
  Parameter angegeben werden.

  Falls in einer exe-Datei die Karte mit Höhenlinien enthalten ist, wird eine
  img-Datei mit der Karte und eine zweite img-Datei nur mit den Höhenlinien
  erstellt. So können die Karte und Höhenlinien unabhängig am GPS-Gerät
  aktiviert werden. Beim Oregon 450 funktioniert das zumindest. Der Name der
  Karte nur mit den Höhenlinien wird im Oregon
  450 mit "... srtm ..." angezeigt.

  Durch entfernen des Kommentarzeichens '#' in Zeile 124 wird auch eine
  img-Datei erstellt, die Karte und Höhenlinien enthält. Am Oregon 450 hat das
  den Nachteil, das in der Liste der verfügbaren Karten je ein Eintrag für die
  Karte und die Höhenlinien steht, allerdings haben beiden den gleichen Namen
  und können nicht unterschieden werden. Darum benutze ich lieber getrennte
  img-Dateien für Karte und Höhenlinien.

  Die img-Dateien für Rheinland-Pfalz, erstellt aus mtbrheinland-pfalz.exe
  heißen zum Beispiel:

    openmtbmap_de-rp_2012-03-22_clas.img
    openmtbmap_de-rp_2012-03-22_clas_srtm.img
               |     |          |    `- Datei mit Höhenlinien (srtm) oder ohne
               |     |          `- Typ-Style "clas", siehe build.rb in Zeile 254
               |     `- Datum der Datei mtbrheinland-pfalz.exe
               `- Land, siehe build.rb ab Zeile 193 in Methode short_map_name()

  Die img-Dateien einfach auf die Speicherkarte des GPS-Gerät kopieren ins
  Verzeichnis Garmin/.

Notwendige Programme
 - Für download.sh:
   - Bash Shell
   - wget
   - tar
   - grep
 - Für build.rb:
   - Ruby (bisher benutzt mit 1.8 und 1.9)
   - Java Laufzeitumgebung (bisher getestet mit OpenJDK/Icedtea 7)
   - 7-Zip für Linux (p7zip)

Beispiel:

# cat urls.txt
ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/germany/mtbrheinland-pfalz.exe
ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/germany/mtbsaarland.exe
ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/mtbluxembourg.exe

# ./download.sh
--2012-03-25 13:00:40--  ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/germany/mtbrheinland-pfalz.exe
[...]
Datei auf dem Server nicht neuer als die lokale Datei »»mtbrheinland-pfalz.exe«« -- kein Download.
--2012-03-25 13:00:40--  ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/germany/mtbsaarland.exe
[...]
Datei auf dem Server nicht neuer als die lokale Datei »»mtbsaarland.exe«« -- kein Download.
--2012-03-25 13:00:41--  ftp://ftp5.gwdg.de/pub/misc/openstreetmap/openmtbmap/mtbluxembourg.exe
[...]
Datei auf dem Server nicht neuer als die lokale Datei »»mtbluxembourg.exe«« -- kein Download.
--2012-03-25 13:00:39--  http://www.mkgmap.org.uk/snapshots/mkgmap-latest.tar.gz
[...]
Datei auf dem Server nicht neuer als die lokale Datei »»mkgmap-latest.tar.gz«« -- kein Download.

mkgmap-r2248/mkgmap.jar
„mkgmap.jar“ -> „mkgmap-2248.jar“

# ./build.rb
mtbluxembourg.exe
  openmtbmap_lu_2012-03-22_clas.img
  openmtbmap_lu_2012-03-22_clas_srtm.img
mtbrheinland-pfalz.exe
  openmtbmap_de-rp_2012-03-22_clas.img
  openmtbmap_de-rp_2012-03-22_clas_srtm.img
mtbsaarland.exe
  openmtbmap_de-sa_2012-03-22_clas.img
  openmtbmap_de-sa_2012-03-22_clas_srtm.img

# ls -lh *.img
-rw-r--r-- 1 daniel daniel  69M 22. Mär 00:00 openmtbmap_de-rp_2012-03-22_clas.img
-rw-r--r-- 1 daniel daniel 3,3M 22. Mär 00:00 openmtbmap_de-rp_2012-03-22_clas_srtm.img
-rw-r--r-- 1 daniel daniel  15M 22. Mär 00:00 openmtbmap_de-sa_2012-03-22_clas.img
-rw-r--r-- 1 daniel daniel 449K 22. Mär 00:00 openmtbmap_de-sa_2012-03-22_clas_srtm.img
-rw-r--r-- 1 daniel daniel  11M 22. Mär 00:00 openmtbmap_lu_2012-03-22_clas.img
-rw-r--r-- 1 daniel daniel 787K 22. Mär 00:00 openmtbmap_lu_2012-03-22_clas_srtm.img
