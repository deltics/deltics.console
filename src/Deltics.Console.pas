
  unit Deltics.Console;

interface

  uses
    Classes,
    Deltics.Strings;

  type
    TCursorPos = record
      Col: SmallInt;
      Row: SmallInt;
    end;

    ConsoleColor = (BLACK,    DKBLUE, DKGREEN, DKCYAN, DKRED, PURPLE, DKYELLOW, SILVER,
                    GRAPHITE,   BLUE,   GREEN,   CYAN,   RED,   PINK,   YELLOW, WHITE);

    Console = class
    private
      class procedure ParseVariables(var aMessage: String; aArgs: array of const);
      class function SetColor(aAttr: Word): Word; overload;
      class function SetColor(aFG: Byte): Word; overload;
      class function SetColor(aFG, aBG: Byte): Word; overload;

      // TODO: Revisit the way this works:
      // class procedure ClearProcessingMessage;
      // class procedure SetProcessingMessage(const aMessage: UnicodeString);

      // TODO: Also to be revisited:
      // class procedure Write(const aList: TStrings; const aLeftMargin: Integer); overload;
      class procedure Write(const aList: TStrings; const aLeftMargin, aRightMargin: Integer); overload;
    public
      class function Attr: Word;
      class function CursorPos: TCursorPos;
      class function Size: TCursorPos;
      class function SetCursorPos(aCoord: TCursorPos): TCursorPos;
      class function Tab(aCols: Word): TCursorPos;
      class function TabTo(aCol: Word): TCursorPos;

      class procedure ClearLine(aPos: TCursorPos); overload;
      class procedure ClearLine(aRow: SmallInt); overload;

      class procedure ErrorLn(const aString: String); overload;
      class procedure ErrorLn(const aString: String; aArgs: array of const); overload;

      class procedure Indent(const aIndent: Integer);
      class procedure NoIndent;
      class procedure Unindent;

      class procedure Write(const aList: TStrings); overload;
      class procedure Write(const aList: TStringArray); overload;

      class procedure Write(const aColor: ConsoleColor; const aString: String); overload;
      class procedure Write(const aString: String); overload;
      class procedure Write(const aString: String; aArgs: array of const); overload;
      class procedure WriteLn(const aString: String = ''); overload;
      class procedure WriteLn(const aString: String; aArgs: array of const); overload;
    end;
    ConsoleClass = class of Console;


implementation

  uses
    SysUtils,
    Windows,
    Deltics.Strings.Types;


  const
    ATTR_INTENSE   = $08;
    ATTR_NO_CHANGE = $ff;

    ATTR_BLACK     = $00;
    ATTR_SILVER    = $07;
    ATTR_GRAPHITE  = $08;
    ATTR_WHITE     = $0f;

    ATTR_BLUE      = $01;
    ATTR_GREEN     = $02;
    ATTR_RED       = $04;
    ATTR_YELLOW    = ATTR_RED   or ATTR_GREEN;
    ATTR_CYAN      = ATTR_GREEN or ATTR_BLUE;
    ATTR_MAGENTA   = ATTR_RED   or ATTR_BLUE;

    ATTR_INTENSE_BLUE    = ATTR_BLUE    or ATTR_INTENSE;
    ATTR_INTENSE_GREEN   = ATTR_GREEN   or ATTR_INTENSE;
    ATTR_INTENSE_RED     = ATTR_RED     or ATTR_INTENSE;
    ATTR_INTENSE_YELLOW  = ATTR_YELLOW  or ATTR_INTENSE;
    ATTR_INTENSE_CYAN    = ATTR_CYAN    or ATTR_INTENSE;
    ATTR_INTENSE_MAGENTA = ATTR_MAGENTA or ATTR_INTENSE;

    COLOR_ATTR  : array[ConsoleColor] of Byte = (ATTR_BLACK,
                                                 ATTR_BLUE,
                                                 ATTR_GREEN,
                                                 ATTR_CYAN,
                                                 ATTR_RED,
                                                 ATTR_MAGENTA,
                                                 ATTR_YELLOW,
                                                 ATTR_SILVER,
                                                 ATTR_GRAPHITE,
                                                 ATTR_BLUE    or ATTR_INTENSE,
                                                 ATTR_GREEN   or ATTR_INTENSE,
                                                 ATTR_CYAN    or ATTR_INTENSE,
                                                 ATTR_RED     or ATTR_INTENSE,
                                                 ATTR_MAGENTA or ATTR_INTENSE,
                                                 ATTR_YELLOW  or ATTR_INTENSE,
                                                 ATTR_WHITE
                                                );

  var
    Indent: Integer;
    Indents: array of Integer;
    NewLine: Boolean = TRUE;


{ Console }

(*
  var
    fProcessMessagePos: TCursorPos;
    fProcessMessage: Boolean = FALSE;
*)

  class procedure Console.ClearLine(aPos: TCursorPos);
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
    pos: TCursorPos;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    pos := SetCursorPos(aPos);
    Write(STR.StringOf(' ', csbi.dwSize.X - aPos.Col - 1));
    SetCursorPos(pos);
  end;


  class procedure Console.ClearLine(aRow: SmallInt);
  var
    pos: TCursorPos;
  begin
    pos.Row := aRow;
    pos.Col := 0;

    ClearLine(pos);
  end;


(*
  class procedure Console.ClearProcessingMessage;
  begin
    if NOT fProcessMessage then
      EXIT;

    fProcessMessage := FALSE;

    Console.ClearLine(fProcessMessagePos);
    Console.SetCursorPos(fProcessMessagePos);
  end;
*)

  class function Console.CursorPos: TCursorPos;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    result.Col := csbi.dwCursorPosition.X;
    result.Row := csbi.dwCursorPosition.Y;
  end;


  class procedure Console.ErrorLn(const aString: String);
  var
    attr: Word;
  begin
    attr := SetColor(ATTR_RED + ATTR_INTENSE);
    try
      WriteLn(aString);

    finally
      SetColor(attr);
    end;
  end;


  class procedure Console.ErrorLn(const aString: String;
                                        aArgs: array of const);
  var
    attr: Word;
  begin
    attr := SetColor(ATTR_RED + ATTR_INTENSE);
    try
      WriteLn(aString, aArgs);

    finally
      SetColor(attr);
    end;
  end;


  class procedure Console.Indent(const aIndent: Integer);
  var
    i: Integer;
    idx: Integer;
  begin
    idx := Length(Indents);

    SetLength(Indents, idx + 1);
    Indents[idx] := aIndent;

    Deltics.Console.Indent := 0;
    for i := 0 to idx do
      Inc(Deltics.Console.Indent, Indents[i]);
  end;


  class procedure Console.NoIndent;
  begin
    SetLength(Indents, 0);
    Deltics.Console.Indent := 0;
  end;


  class procedure Console.ParseVariables(var aMessage: String;
                                             aArgs: array of const);
  var
    i: Integer;
    msgLen: Integer;
    inPropertyRef: Boolean;
    propertyRef: String;
    refs: IStringList;
    names: IStringList;
    firstRef: IStringList;
    name: String;
    formatSpec: String;
    argIndex: Integer;
  begin
    inPropertyRef := FALSE;
    propertyRef   := '';

    refs := TComInterfacedStringList.Create;

    i       := 1;
    msgLen  := Length(aMessage);
    while i <= msgLen do
    begin
      if inPropertyRef and (aMessage[i] = '}') then
      begin
        inPropertyRef := FALSE;

        refs.Add(propertyRef.ToLower);
      end
      else if (aMessage[i] = '{') then
      begin
        if (i < msgLen) and (aMessage[i + 1] <> '{') then
        begin
          inPropertyRef := TRUE;
          propertyRef   := '';
        end
        else
          Inc(i);
      end
      else if (aMessage[i] = '}') then
      begin
        if (i < msgLen) and (aMessage[i + 1] = '}') then
          Inc(i)
        else
          raise Exception.CreateFmt('Error in interpolated string ''%s''.'#13'Found ''}'' at %d but but expected ''}}''.', [aMessage, i]);
      end
      else
        propertyRef := propertyRef + aMessage[i];

      Inc(i);
    end;

    names := TComInterfacedStringList.Create;
    names.Unique := TRUE;

    firstRef := TComInterfacedStringList.Create;

    for i := 0 to Pred(refs.Count) do
    begin
      propertyRef := refs[i];
      STR.Split(propertyRef, ':', name, formatSpec);

      if NOT firstRef.ContainsName(name) then
      begin
        if formatSpec = '' then
          formatSpec := '%s';

        firstRef.Add(name + '=' + formatSpec)
      end
      else if formatSpec = '' then
        formatSpec := firstRef.Values[name];

      STR.DeleteLeft(formatSpec, 1);

      argIndex    := names.Add(name);
      formatSpec  := '%' + IntToStr(argIndex) + ':' + formatSpec;

      aMessage := StringReplace(aMessage, '{' + propertyRef + '}', formatSpec, [rfReplaceAll]);
    end;

    aMessage := Format(aMessage, aArgs);
  end;


  class procedure Console.Unindent;
  var
    i: Integer;
  begin
    if Length(Indents) = 0 then
    begin
      Deltics.Console.Indent := 0;
      EXIT;
    end;

    SetLength(Indents, Length(Indents) - 1);

    Deltics.Console.Indent := 0;
    for i := 0 to High(Indents) do
      Inc(Deltics.Console.Indent, Indents[i]);
  end;


  class function Console.Attr: Word;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    result := csbi.wAttributes;
  end;


  class function Console.SetColor(aAttr: Word): Word;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    result := csbi.wAttributes;

    SetConsoleTextAttribute(stdOut, aAttr);
  end;


  class function Console.SetColor(aFG: Byte): Word;
  begin
    result := SetColor(aFG, ATTR_NO_CHANGE);
  end;


  class function Console.SetColor(aFG, aBG: Byte): Word;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
    attr: Word;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    attr    := csbi.wAttributes;
    result  := attr;

    if aFG <> ATTR_NO_CHANGE then
      attr  := (attr and $fff0) or aFG;

    if aBG <> ATTR_NO_CHANGE then
      attr  := (attr and $ff0f) or (aBG shl 4);

    SetColor(attr);
  end;


  class function Console.SetCursorPos(aCoord: TCursorPos): TCursorPos;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
    pos: _COORD;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    result.Col := csbi.dwCursorPosition.X;
    result.Row := csbi.dwCursorPosition.Y;

    pos.X := aCoord.Col;
    pos.Y := aCoord.Row;

    SetConsoleCursorPosition(stdOut, pos);
  end;


(*
  class procedure Console.SetProcessingMessage(const aMessage: UnicodeString);
  begin
    if NOT fProcessMessage then
    begin
      if CursorPos.Col > 0 then
        Console.WriteLn;

      fProcessMessagePos := CursorPos;
    end
    else
      Console.SetCursorPos(fProcessMessagePos);

    Console.Write(GRAPHITE, aMessage);

    fProcessMessage := TRUE;
  end;
*)


  class function Console.Size: TCursorPos;
  var
    stdOut: THandle;
    csbi: TConsoleScreenBufferInfo;
  begin
    stdOut := GetStdHandle(STD_OUTPUT_HANDLE);

    GetConsoleScreenBufferInfo(stdOut, csbi);

    result.Col := csbi.dwSize.X;
    result.Row := csbi.dwSize.Y;
  end;


  class function Console.Tab(aCols: Word): TCursorPos;
  begin
    result := CursorPos;
    result.Col := result.Col + aCols;
    result := SetCursorPos(result);
  end;


  class function Console.TabTo(aCol: Word): TCursorPos;
  begin
    result := CursorPos;
    result.Col := aCol;
    result := SetCursorPos(result);
  end;




  class procedure Console.Write(const aString: String);

    function ExtractColor(var aString: String;
                          const aColorName: String;
                          const aColor: Byte;
                          var aResult: Byte): Boolean;
    begin
      result := STR.ConsumeLeft(aString, aColorName, csIgnoreCase);
      if result then
        aResult := aColor;
    end;

    function ParseColor(var aString: String;
                        var aColor: Byte): Boolean;
    begin
      result := ExtractColor(aString, 'black',    ATTR_BLACK,    aColor)
             or ExtractColor(aString, 'graphite', ATTR_GRAPHITE, aColor)
             or ExtractColor(aString, 'silver',   ATTR_SILVER,   aColor)
             or ExtractColor(aString, 'white',    ATTR_WHITE,    aColor)

             or ExtractColor(aString, 'red',      ATTR_INTENSE_RED,      aColor)
             or ExtractColor(aString, 'green',    ATTR_INTENSE_GREEN,    aColor)
             or ExtractColor(aString, 'blue',     ATTR_INTENSE_BLUE,     aColor)
             or ExtractColor(aString, 'cyan',     ATTR_INTENSE_CYAN,     aColor)
             or ExtractColor(aString, 'yellow',   ATTR_INTENSE_YELLOW,   aColor)
             or ExtractColor(aString, 'pink',     ATTR_INTENSE_MAGENTA,  aColor)

             or ExtractColor(aString, 'dkred',    ATTR_RED,      aColor)
             or ExtractColor(aString, 'dkgreen',  ATTR_GREEN,    aColor)
             or ExtractColor(aString, 'dkblue',   ATTR_BLUE,     aColor)
             or ExtractColor(aString, 'dkcyan',   ATTR_CYAN,     aColor)
             or ExtractColor(aString, 'dkyellow', ATTR_YELLOW,   aColor)
             or ExtractColor(aString, 'purple',   ATTR_MAGENTA,  aColor);
    end;

    function ParseAttr(var aString: String;
                       var aFG: Byte;
                       var aBG: Byte;
                       var aOutput: String): Boolean;
    var
      s: String;
      i, parens: Integer;
    begin
      aFG := ATTR_NO_CHANGE;
      aBG := ATTR_NO_CHANGE;
      result := FALSE;

      s := aString;

      if NOT ParseColor(s, aFG) then
        EXIT;

      if Copy(s, 1, 1) = '|' then
      begin
        Delete(s, 1, 1);
        if NOT ParseColor(s, aBG) then
          EXIT;
      end;

      if Copy(s, 1, 1) <> '(' then
        EXIT;

      parens := 0;
      for i := 1 to Length(s) do
        case s[i] of
          '(' : Inc(parens);
          ')' : begin
                  Dec(parens);
                  if parens = 0 then
                  begin
                    aOutput := Copy(s, 2, i - 2);
                    Delete(s, 1, i);
                    aString := s;
                    result := TRUE;
                    EXIT;
                  end;
                end;
        end;
    end;

  var
    s: String;
    ap: Integer;
    output: String;
    attr: Word;
    fg, bg: Byte;
  begin
//    ClearProcessingMessage;

    s := aString;

    if s = '' then
      EXIT;

    if NewLine and (Deltics.Console.Indent > 0) then
    begin
      System.Write(STR.StringOf(' ', Deltics.Console.Indent));
      NewLine := FALSE;
    end;

    while STR.Find(s, '@', ap) do
    begin
      // First output everything up to the @

      output := Copy(s, 1, ap - 1);
      Delete(s, 1, ap);

      System.Write(output);

      // Now determine whether the @ represents an attribute tag

      if ParseAttr(s, fg, bg, output) then
      begin
        attr := Console.SetColor(fg, bg);
        System.Write(output);
        SetColor(attr);
      end
      else // Not a (valid) attr so just output the @ and carry on...
        System.Write('@');
    end;

    System.Write(s);
  end;

  class procedure Console.Write(const aString: String;
                                      aArgs: array of const);
  var
    msg: String;
  begin
    msg := aString;
    ParseVariables(msg, aArgs);
    Write(Format(msg, aArgs));
  end;


  class procedure Console.WriteLn(const aString: String);
  begin
    Write(aString);
    System.WriteLn;

    NewLine := TRUE;
  end;


  class procedure Console.Write(const aColor: ConsoleColor;
                                const aString: String);
  var
    attr: Word;
  begin
    attr := SetColor(COLOR_ATTR[aColor]);
    Console.Write(aString);
    SetColor(attr);
  end;


  class procedure Console.Write(const aList: TStringArray);
  var
    i: Integer;
  begin
    for i := 0 to Pred(aList.Count) do
      Console.WriteLn(aList[i]);
  end;


  class procedure Console.Write(const aList: TStrings);
  begin
    Write(aList, 0, 0);
  end;


(*
  class procedure Console.Write(const aList: TStrings;
                                const aLeftMargin: Integer);
  begin
    Write(aList, aLeftMargin, 0);
  end;
*)


  class procedure Console.Write(const aList: TStrings;
                                const aLeftMargin, aRightMargin: Integer);
  var
    i: Integer;
  begin
    for i := 0 to Pred(aList.Count) do
      Console.WriteLn(aList[i]);
  end;


  class procedure Console.WriteLn(const aString: String;
                                        aArgs: array of const);
  var
    msg: String;
  begin
    msg := aString;
    ParseVariables(msg, aArgs);
    WriteLn(Format(msg, aArgs));
  end;



end.
