procedure TBaseForm.UpdateBands;
var
  StarsActive, count, x, y: Integer;
  cR, cG, cB: Integer;
  i: Integer;
  Bmp: TBitmap;
begin
  if not FReady then Exit;
  if not Assigned(Image) then Exit;
  
  Bmp := Image.Picture.Bitmap;

  // 1. Очищаем фон
  with Bmp.Canvas do
  begin
    Brush.Color := clBlack;
    FillRect(0, 0, IMG_W, IMG_H);
  end;

  StarsActive := 0;

  // 2. ОДИН цикл: считаем активные и сразу рисуем
  for y := 0 to High(StarColor) do
    for x := 0 to High(StarColor[y]) do
    begin
      // Считаем активные
      if StarState[y, x] <> 0 then
        Inc(StarsActive);

      // Если звезда неактивна — пропускаем отрисовку
      if StarState[y, x] = 0 then Continue;

      // Логика яркости (Fade In / Fade Out)
      case StarState[y, x] of
        1: begin
             Inc(StarBright[y, x], FadeInStep);
             if StarBright[y, x] >= 255 then
             begin
               StarBright[y, x] := 255;
               StarState[y, x]  := 2;
             end;
           end;
        2: begin
             Dec(StarBright[y, x], FadeOutStep);
             if StarBright[y, x] <= 0 then
             begin
               StarBright[y, x] := 0;
               StarState[y, x]  := 0;
               // Звезда умерла, не рисуем её в этом кадре
               Continue; 
             end;
           end;
      end;

      // Расчет цвета с учётом яркости
      cR := (StarColor[y, x].R * StarBright[y, x]) div 255;
      cG := (StarColor[y, x].G * StarBright[y, x]) div 255;
      cB := (StarColor[y, x].B * StarBright[y, x]) div 255;

      if (cR = 0) and (cG = 0) and (cB = 0) then Continue;

      // ОТРИСОВКА: заполняем ВСЮ клетку цветом звезды
      Bmp.Canvas.Brush.Color := RGBToColor(cR, cG, cB);
      Bmp.Canvas.FillRect(
        x * CELL_W,
        y * CELL_H,
        (x + 1) * CELL_W,
        (y + 1) * CELL_H
      );
    end;

  // 3. Спавн новых звёзд (только если лимит не достигнут)
  if StarsActive < MaxStars then
  begin
    for count := 1 to 5 do
    begin
      if Random(100) < SpawnChance then
      begin
        y := Random(ROWS);
        x := Random(COLS);
        if StarState[y, x] = 0 then
        begin
          StarColor[y, x].R := Random(256);
          StarColor[y, x].G := Random(256);
          StarColor[y, x].B := Random(256);
          StarBright[y, x] := 0;
          StarState[y, x]  := 1;
        end;
      end;
    end;
  end;

  // 4. Ленты (оставляем как есть)
  TrySpawnBand;
  i := 0;
  while i < BandsCount do
  begin
    if Bands[i].Fade < 255 then
      Inc(Bands[i].Fade, BAND_FADE_STEP);

    case Bands[i].Direction of
      0: begin Bands[i].CellX1 := Bands[i].CellX1 + Bands[i].SpeedX; if Bands[i].CellX1 > COLS then SpawnBand(Bands[i]); end;
      1: begin Bands[i].CellY1 := Bands[i].CellY1 + Bands[i].SpeedY; if Bands[i].CellY1 > ROWS then SpawnBand(Bands[i]); end;
      2: begin Bands[i].CellX1 := Bands[i].CellX1 - Bands[i].SpeedX; if Bands[i].CellX1 < -Bands[i].CellW then SpawnBand(Bands[i]); end;
      3: begin Bands[i].CellY1 := Bands[i].CellY1 - Bands[i].SpeedY; if Bands[i].CellY1 < -Bands[i].CellH then SpawnBand(Bands[i]); end;
    end;

    DrawBand(Bmp, Bands[i]);
    Inc(i);
  end;

  Image.Repaint;
end;
