{
  stdenv,
  lib,
  fetchurl,
  SDL,
  SDL2,
  SDL2_image,
  SDL2_mixer,
  fmodex,
  dwarf-fortress-unfuck,
  autoPatchelfHook,

  # Our own "unfuck" libs for macOS
  ncurses,
  gcc,

  dfVersion,
  dfVersions,
}:

let
  inherit (lib)
    attrNames
    elemAt
    getAttr
    getLib
    hasAttr
    licenses
    maintainers
    optional
    optionals
    optionalString
    splitVersion
    toInt
    ;

  # Map Dwarf Fortress platform names to Nixpkgs platform names.
  platforms = {
    x86_64-linux = "linux";
    x86_64-darwin = "darwin";
  };

  dfVersionTuple = splitVersion dfVersion;
  dfVersionBaseIndex =
    let
      x = (builtins.length dfVersionTuple) - 2;
    in
    if x >= 0 then x else 0;
  baseVersion = toInt (elemAt dfVersionTuple dfVersionBaseIndex);
  patchVersion = elemAt dfVersionTuple (dfVersionBaseIndex + 1);

  isAtLeast50 = baseVersion >= 50;
  enableUnfuck =
    !isAtLeast50
    && dwarf-fortress-unfuck != null
    && (dwarf-fortress-unfuck.dfVersion or null) == dfVersion;

  game =
    if hasAttr dfVersion dfVersions.game.versions then
      (getAttr dfVersion dfVersions.game.versions).df
    else
      throw "Unknown Dwarf Fortress version: ${dfVersion}";
  dfPlatform =
    if hasAttr stdenv.hostPlatform.system platforms then
      getAttr stdenv.hostPlatform.system platforms
    else
      throw "Unsupported system: ${stdenv.hostPlatform.system}";
  url =
    if hasAttr dfPlatform game.urls then
      getAttr dfPlatform game.urls
    else
      throw "Unsupported dfPlatform: ${dfPlatform}";
  exe =
    if stdenv.hostPlatform.isLinux then
      if baseVersion >= 50 then "dwarfort" else "libs/Dwarf_Fortress"
    else
      "dwarfort.exe";
in

stdenv.mkDerivation {
  pname = "dwarf-fortress";
  version = dfVersion;

  src = fetchurl {
    inherit (url) url;
    hash = url.outputHash;
  };

  sourceRoot = ".";

  postUnpack = ''
    directory=${
      if stdenv.hostPlatform.isLinux then
        "df_linux"
      else if stdenv.hostPlatform.isDarwin then
        "df_osx"
      else
        throw "Unsupported system"
    }
    if [ -d "$directory" ]; then
      mv "$directory/"* .
    fi
  '';

  nativeBuildInputs = optional stdenv.hostPlatform.isLinux autoPatchelfHook;
  buildInputs =
    optionals isAtLeast50 [
      SDL2
      SDL2_image
      SDL2_mixer
    ]
    ++ optional (!isAtLeast50) SDL
    ++ optional enableUnfuck dwarf-fortress-unfuck
    ++ [ (lib.getLib stdenv.cc.cc) ];

  installPhase = ''
    runHook preInstall

    exe=$out/${exe}
    mkdir -p $out
    cp -r * $out

    # Clean up OS X detritus in the tarball.
    find $out -type f -name '._*' -exec rm -rf {} \;

    # Lots of files are +x in the newer releases...
    find $out -type d -exec chmod 0755 {} \;
    find $out -type f -exec chmod 0644 {} \;
    chmod +x $exe
    [ -f $out/df ] && chmod +x $out/df
    [ -f $out/run_df ] && chmod +x $out/run_df

    # We don't need any of these since they will just break autoPatchelf on <version 50.
    [ -d $out/libs ] && rm -rf $out/libs/*.so $out/libs/*.so.* $out/libs/*.dylib

    # Store the original hash
    md5sum $exe | awk '{ print $1 }' > $out/hash.md5.orig
    echo "Original MD5: $(<$out/hash.md5.orig)" >&2
  ''
  + optionalString stdenv.hostPlatform.isDarwin ''
    # My custom unfucked dwarfort.exe for macOS. Can't use
    # absolute paths because original doesn't have enough
    # header space. Someone plz break into Tarn's house & put
    # -headerpad_max_install_names into his LDFLAGS.

    ln -s ${getLib ncurses}/lib/libncurses.dylib $out/libs
    ln -s ${getLib gcc.cc}/lib/libstdc++.6.dylib $out/libs
    ln -s ${getLib gcc.cc}/lib/libgcc_s.1.dylib $out/libs
    ln -s ${getLib fmodex}/lib/libfmodex.dylib $out/libs

    install_name_tool \
      -change /usr/lib/libncurses.5.4.dylib \
              @executable_path/libs/libncurses.dylib \
      -change /usr/local/lib/x86_64/libstdc++.6.dylib \
              @executable_path/libs/libstdc++.6.dylib \
      $exe
  ''
  + ''
    runHook postInstall
  '';

  preFixup = ''
    recompute_hash() {
      # Store the new hash as the very last step.
      exe=$out/${exe}
      md5sum $exe | awk '{ print $1 }' > $out/hash.md5
      echo "Patched MD5: $(<$out/hash.md5)" >&2
    }

    # Ensure that this runs after autoPatchelfHook.
    trap recompute_hash EXIT
  '';

  passthru = {
    inherit
      baseVersion
      patchVersion
      dfVersion
      exe
      ;
    updateScript = {
      command = [ ./update.rb ];
      attrPath = "dwarf-fortress-packages";
      supportedFeatures = [ "commit" ];
    };
  };

  meta = {
    description = "Single-player fantasy game with a randomly generated adventure world";
    homepage = "https://www.bay12games.com/dwarves/";
    license = licenses.unfreeRedistributable;
    platforms = attrNames platforms;
    maintainers = with maintainers; [
      a1russell
      robbinch
      roconnor
      abbradar
      numinit
      shazow
      ncfavier
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
