//+------------------------------------------------------------------+
//|                                    VFI_LazyBear_Enhanced.mq5     |
//|                        Copyright 2025, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.01"
#property description "Volume Flow Indicator [LazyBear] Enhanced - with Alerts, Signals, Auto Zones & Divergences"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   5

//--- plot VFI
#property indicator_label1  "VFI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot VFI EMA
#property indicator_label2  "EMA of VFI"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- plot Histogram
#property indicator_label3  "Histogram"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrGray
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- plot Buy Arrows
#property indicator_label4  "Buy Signal"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3
#property indicator_style4  STYLE_SOLID

//--- plot Sell Arrows
#property indicator_label5  "Sell Signal"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3
#property indicator_style5  STYLE_SOLID

//+------------------------------------------------------------------+
//| Function declarations                                            |
//+------------------------------------------------------------------+
bool IsRussianSystem();
string GetLocalizedText(string key);
string GetComputerUserName();
string GetCurrentDateTime();
string GetSessionUptime();
void SendAlert(AlertType alert_type, string message, int bar_index = 0);
void CalculateDynamicZones(int current_bar);
void CreateZoneObjects(int current_bar);
bool IsLocalMaximum(const double &buffer[], int pos, int lookback = 5);
bool IsLocalMinimum(const double &buffer[], int pos, int lookback = 5);
void DetectDivergences(const double &close[], int current_bar);
void DrawDivergenceLine(string name, int bar1, int bar2, color line_color, bool is_bullish);
void UpdateInfoPanel(int current_bar);
void CheckVolumeData();
void CheckSignalsAndAlerts(int current_bar, const double &close[]);
double CalculateStdDev(int pos, int period);
int CopyTickVolumeData(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, long &tick_volume_array[]);

//+------------------------------------------------------------------+
//| Custom tick volume copy function                                |
//+------------------------------------------------------------------+
int CopyTickVolumeData(string symbol, ENUM_TIMEFRAMES timeframe, int start_pos, int count, long &tick_volume_array[])
{
    MqlRates rates[];
    int copied = CopyRates(symbol, timeframe, start_pos, count, rates);
    
    if(copied <= 0)
        return 0;
    
    ArrayResize(tick_volume_array, copied);
    
    for(int i = 0; i < copied; i++)
    {
        tick_volume_array[i] = rates[i].tick_volume;
    }
    
    return copied;
}

//--- Original input parameters
input int      VFI_Length = 130;        // VFI length
input double   Coef = 0.2;              // Coefficient
input double   VCoef = 2.5;             // Max. vol. cutoff
input int      SignalLength = 5;        // Signal length
input bool     SmoothVFI = false;       // Smooth VFI
input bool     ShowHisto = false;       // Show Histogram
input bool     UseRealVolume = false;   // Use Real Volume (if available)

//--- New Alert System
input group "=== ALERT SYSTEM ==="
input bool     EnableAlerts = true;           // Enable Alerts
input bool     AlertOnZeroCross = true;       // Alert on Zero Line Cross
input bool     AlertOnEMACross = true;        // Alert on EMA Cross
input bool     AlertOnZones = true;           // Alert on Overbought/Oversold
input bool     AlertOnDivergence = true;      // Alert on Divergence
input bool     ShowPopupAlerts = true;        // Show Popup Alerts
input bool     PlaySoundAlerts = true;        // Play Sound Alerts
input bool     SendPushAlerts = false;        // Send Push Notifications
input string   AlertSoundFile = "alert.wav";  // Alert Sound File

//--- Visual Signals
input group "=== VISUAL SIGNALS ==="
input bool     ShowArrows = true;             // Show Signal Arrows
input bool     ShowSignalLabels = true;       // Show Signal Labels
input color    BuyArrowColor = clrLime;       // Buy Arrow Color
input color    SellArrowColor = clrRed;       // Sell Arrow Color
input int      ArrowSize = 2;                 // Arrow Size

//--- Auto Zones
input group "=== AUTO ZONES ==="
input bool     ShowAutoZones = true;          // Show Auto Overbought/Oversold Zones
input int      ZoneCalculationPeriod = 200;   // Zone Calculation Period
input double   ZonePercentile = 80.0;         // Zone Percentile (80% = top 20%)
input color    OverboughtZoneColor = clrLightCoral;   // Overbought Zone Color
input color    OversoldZoneColor = clrLightGreen;     // Oversold Zone Color
input int      ZoneTransparency = 70;         // Zone Transparency (0-100)

//--- Divergence Detection
input group "=== DIVERGENCE DETECTION ==="
input bool     DetectDivergences = true;      // Detect Divergences
input int      DivergenceBars = 50;           // Divergence Analysis Period
input int      MinDivergenceDistance = 10;    // Minimum Distance Between Peaks
input bool     ShowDivergenceLines = true;    // Show Divergence Lines
input color    BullishDivergenceColor = clrGreen;     // Bullish Divergence Color
input color    BearishDivergenceColor = clrRed;       // Bearish Divergence Color
input int      DivergenceLineWidth = 2;       // Divergence Line Width

//--- Info Panel
input group "=== INFO PANEL ==="
input bool     ShowInfoPanel = true;          // Show Info Panel
input int      PanelX = 10;                   // Panel X Position
input int      PanelY = 30;                   // Panel Y Position
input color    PanelColor = clrDarkSlateGray; // Panel Background Color
input color    TextColor = clrWhite;          // Panel Text Color
input int      FontSize = 9;                  // Panel Font Size

//--- indicator buffers
double VFI_Buffer[];
double VFI_EMA_Buffer[];
double Histogram_Buffer[];
double VCP_Buffer[];
double BuyArrow_Buffer[];
double SellArrow_Buffer[];
double UpperZone_Buffer[];
double LowerZone_Buffer[];

//--- arrays for calculations
double inter_array[];
double typical_array[];

//--- global variables
bool real_volumes_available = false;
bool is_russian_system = false;
int last_calculated = 0;

//--- System info constants - ИНТЕГРАЦИЯ ДАННЫХ
const string SYSTEM_USER = "xs99ewti";                    // Интегрированный пользователь
const string SYSTEM_UTC_TIME = "2025-07-28 20:04:06";    // Базовое время UTC

//--- Alert system variables
datetime last_alert_time[10]; // Array to store last alert times for different types
int last_alert_bar[10]; // Array to store last alert bar for different types
enum AlertType
{
    ALERT_ZERO_CROSS_UP = 0,
    ALERT_ZERO_CROSS_DOWN = 1,
    ALERT_EMA_CROSS_UP = 2,
    ALERT_EMA_CROSS_DOWN = 3,
    ALERT_OVERBOUGHT = 4,
    ALERT_OVERSOLD = 5,
    ALERT_BULLISH_DIV = 6,
    ALERT_BEARISH_DIV = 7
};

//--- Zone calculation variables
double dynamic_overbought_level = 0;
double dynamic_oversold_level = 0;

//--- Info panel variables
string panel_name = "VFI_InfoPanel";

//--- Session tracking
datetime session_start_time;
int total_signals_buy = 0;
int total_signals_sell = 0;

//+------------------------------------------------------------------+
//| Определение языка системы                                       |
//+------------------------------------------------------------------+
bool IsRussianSystem()
{
    string terminal_language = TerminalInfoString(TERMINAL_LANGUAGE);
    
    if(terminal_language == "Russian" || terminal_language == "Русский" || 
       StringFind(terminal_language, "RU") >= 0 || StringFind(terminal_language, "ru") >= 0)
    {
        return true;
    }
    
    string test_number = DoubleToString(1.5, 1);
    if(StringFind(test_number, ",") >= 0)
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Получение локализованного текста                                |
//+------------------------------------------------------------------+
string GetLocalizedText(string key)
{
    if(!is_russian_system)
    {
        // English texts
        if(key == "volume_check_header") return "           VFI INDICATOR VOLUME CHECK           ";
        if(key == "symbol") return "Symbol";
        if(key == "datetime") return "Date/time";
        if(key == "user") return "User";
        if(key == "execution_type") return "Execution type";
        if(key == "terminal_paths") return "DEBUG - Terminal paths";
        if(key == "bars_analyzed") return "Bars analyzed";
        if(key == "tick_volumes") return "TICK VOLUMES";
        if(key == "average") return "Average";
        if(key == "maximum") return "Maximum";
        if(key == "minimum") return "Minimum";
        if(key == "zero_bars") return "Bars with zero volume";
        if(key == "real_volumes") return "REAL VOLUMES";
        if(key == "real_volumes_unavailable") return "REAL VOLUMES: Unavailable";
        if(key == "quality_assessment") return "QUALITY ASSESSMENT";
        if(key == "recommendation") return "RECOMMENDATION";
        if(key == "indicator_settings") return "INDICATOR SETTINGS";
        if(key == "will_use_real") return "Will use: REAL VOLUMES";
        if(key == "will_use_tick") return "Will use: TICK VOLUMES";
        if(key == "yes") return "YES";
        if(key == "no") return "NO";
        if(key == "error_no_data") return "❌ ERROR: Could not get price data!";
        if(key == "critical_no_volumes") return "❌ CRITICAL: Very little volume data";
        if(key == "poor_no_variation") return "⚠️ POOR: Volumes hardly change";
        if(key == "satisfactory_tick_only") return "⚠️ SATISFACTORY: Tick volumes only";
        if(key == "excellent_real_volumes") return "✅ EXCELLENT: Quality real volumes";
        if(key == "good_real_gaps") return "✅ GOOD: Real volumes with gaps";
        if(key == "change_instrument") return "Change instrument or broker";
        if(key == "may_work_incorrectly") return "Indicator may work incorrectly";
        if(key == "will_work_less_accurate") return "Indicator will work, but less accurately";
        if(key == "will_work_max_accurate") return "Indicator will work with maximum accuracy";
        if(key == "will_work_correctly") return "Indicator will work correctly";
        if(key == "indicator_finished") return "         VFI INDICATOR FINISHED WORK         ";
        if(key == "reason") return "Reason";
        if(key == "time") return "Time";
        if(key == "parameter_error") return "Parameter Error";
        if(key == "invalid_vfi_length") return "VFI_Length must be >= 10";
        if(key == "invalid_signal_length") return "SignalLength must be >= 1";
        if(key == "invalid_coefficients") return "Coefficients must be positive";
        if(key == "settings_changed") return "Settings changed - recalculating all data";
        if(key == "session_started") return "Session started";
        if(key == "runtime_uptime") return "Runtime uptime";
        if(key == "session_stats") return "Session statistics";
        if(key == "buy_signals") return "Buy signals";
        if(key == "sell_signals") return "Sell signals";
        if(key == "total_signals") return "Total signals";
        
        // New alert texts
        if(key == "vfi_cross_up") return "VFI crossed above zero line";
        if(key == "vfi_cross_down") return "VFI crossed below zero line";
        if(key == "vfi_ema_cross_up") return "VFI crossed above EMA";
        if(key == "vfi_ema_cross_down") return "VFI crossed below EMA";
        if(key == "vfi_overbought") return "VFI entered overbought zone";
        if(key == "vfi_oversold") return "VFI entered oversold zone";
        if(key == "bullish_divergence") return "Bullish divergence detected";
        if(key == "bearish_divergence") return "Bearish divergence detected";
        if(key == "buy_signal") return "BUY";
        if(key == "sell_signal") return "SELL";
        if(key == "current_vfi") return "Current VFI";
        if(key == "trend_status") return "Trend";
        if(key == "signal_strength") return "Signal";
        if(key == "last_signal") return "Last Signal";
        if(key == "bullish") return "Bullish";
        if(key == "bearish") return "Bearish";
        if(key == "neutral") return "Neutral";
        if(key == "strong") return "Strong";
        if(key == "medium") return "Medium";
        if(key == "weak") return "Weak";
        if(key == "none") return "None";
        if(key == "uptime") return "Uptime";
        if(key == "minutes") return "min";
        if(key == "hours") return "h";
        if(key == "days") return "d";
    }
    else
    {
        // Russian texts
        if(key == "volume_check_header") return "           ПРОВЕРКА ОБЪЕМОВ VFI ИНДИКАТОРА           ";
        if(key == "symbol") return "Символ";
        if(key == "datetime") return "Дата/время";
        if(key == "user") return "Пользователь";
        if(key == "execution_type") return "Тип исполнения";
        if(key == "terminal_paths") return "DEBUG - Пути терминала";
        if(key == "bars_analyzed") return "Получено баров для анализа";
        if(key == "tick_volumes") return "ТИКОВЫЕ ОБЪЕМЫ";
        if(key == "average") return "Средний";
        if(key == "maximum") return "Максимальный";
        if(key == "minimum") return "Минимальный";
        if(key == "zero_bars") return "Баров с нулевым объемом";
        if(key == "real_volumes") return "РЕАЛЬНЫЕ ОБЪЕМЫ";
        if(key == "real_volumes_unavailable") return "РЕАЛЬНЫЕ ОБЪЕМЫ: Недоступны";
        if(key == "quality_assessment") return "ОЦЕНКА КАЧЕСТВА";
        if(key == "recommendation") return "РЕКОМЕНДАЦИЯ";
        if(key == "indicator_settings") return "НАСТРОЙКИ ИНДИКАТОРА";
        if(key == "will_use_real") return "Будут использованы: РЕАЛЬНЫЕ ОБЪЕМЫ";
        if(key == "will_use_tick") return "Будут использованы: ТИКОВЫЕ ОБЪЕМЫ";
        if(key == "yes") return "ДА";
        if(key == "no") return "НЕТ";
        if(key == "error_no_data") return "❌ ОШИБКА: Не удалось получить данные по ценам!";
        if(key == "critical_no_volumes") return "❌ КРИТИЧНО: Очень мало данных по объемам";
        if(key == "poor_no_variation") return "⚠️ ПЛОХО: Объемы практически не меняются";
        if(key == "satisfactory_tick_only") return "⚠️ УДОВЛЕТВОРИТЕЛЬНО: Только тиковые объемы";
        if(key == "excellent_real_volumes") return "✅ ОТЛИЧНО: Качественные реальные объемы";
        if(key == "good_real_gaps") return "✅ ХОРОШО: Реальные объемы с пропусками";
        if(key == "change_instrument") return "Смените инструмент или брокера";
        if(key == "may_work_incorrectly") return "Индикатор может работать некорректно";
        if(key == "will_work_less_accurate") return "Индикатор будет работать, но менее точно";
        if(key == "will_work_max_accurate") return "Индикатор будет работать максимально точно";
        if(key == "will_work_correctly") return "Индикатор будет работать корректно";
        if(key == "indicator_finished") return "         VFI ИНДИКАТОР ЗАВЕРШИЛ РАБОТУ         ";
        if(key == "reason") return "Причина";
        if(key == "time") return "Время";
        if(key == "parameter_error") return "Ошибка параметров";
        if(key == "invalid_vfi_length") return "VFI_Length должно быть >= 10";
        if(key == "invalid_signal_length") return "SignalLength должно быть >= 1";
        if(key == "invalid_coefficients") return "Коэффициенты должны быть положительными";
        if(key == "settings_changed") return "Настройки изменены - пересчитываем все данные";
        if(key == "session_started") return "Сессия начата";
        if(key == "runtime_uptime") return "Время работы";
        if(key == "session_stats") return "Статистика сессии";
        if(key == "buy_signals") return "Сигналы покупки";
        if(key == "sell_signals") return "Сигналы продажи";
        if(key == "total_signals") return "Всего сигналов";
        
        // New alert texts in Russian
        if(key == "vfi_cross_up") return "VFI пересек нулевую линию вверх";
        if(key == "vfi_cross_down") return "VFI пересек нулевую линию вниз";
        if(key == "vfi_ema_cross_up") return "VFI пересек EMA вверх";
        if(key == "vfi_ema_cross_down") return "VFI пересек EMA вниз";
        if(key == "vfi_overbought") return "VFI вошел в зону перекупленности";
        if(key == "vfi_oversold") return "VFI вошел в зону перепроданности";
        if(key == "bullish_divergence") return "Обнаружена бычья дивергенция";
        if(key == "bearish_divergence") return "Обнаружена медвежья дивергенция";
        if(key == "buy_signal") return "ПОКУПКА";
        if(key == "sell_signal") return "ПРОДАЖА";
        if(key == "current_vfi") return "Текущий VFI";
        if(key == "trend_status") return "Тренд";
        if(key == "signal_strength") return "Сигнал";
        if(key == "last_signal") return "Последний сигнал";
        if(key == "bullish") return "Бычий";
        if(key == "bearish") return "Медвежий";
        if(key == "neutral") return "Нейтральный";
        if(key == "strong") return "Сильный";
        if(key == "medium") return "Средний";
        if(key == "weak") return "Слабый";
        if(key == "none") return "Нет";
        if(key == "uptime") return "Время работы";
        if(key == "minutes") return "мин";
        if(key == "hours") return "ч";
        if(key == "days") return "д";
    }
    
    return key;
}

//+------------------------------------------------------------------+
//| Получение имени пользователя - ИНТЕГРАЦИЯ                       |
//+------------------------------------------------------------------+
string GetComputerUserName()
{
    // ИНТЕГРАЦИЯ: Используем предоставленный логин
    string username = SYSTEM_USER;
    
    // Дополнительная проверка через терминал (резервный метод)
    string data_path = TerminalInfoString(TERMINAL_DATA_PATH);
    
    if(StringLen(data_path) > 0)
    {
        int pos = StringFind(data_path, "Users\\");
        if(pos >= 0)
        {
            int start = pos + 6;
            int end = StringFind(data_path, "\\", start);
            if(end > start)
            {
                string extracted = StringSubstr(data_path, start, end - start);
                if(StringLen(extracted) > 0 && extracted != "AppData" && 
                   extracted != "Roaming" && extracted != "MetaQuotes")
                {
                    // Если извлеченный пользователь отличается от интегрированного, логируем это
                    if(extracted != SYSTEM_USER)
                    {
                        Print("📋 INFO: Detected user '", extracted, "', but using integrated user '", SYSTEM_USER, "'");
                    }
                }
            }
        }
    }
    
    // Очистка имени пользователя
    StringReplace(username, " ", "_");
    if(StringLen(username) > 20)
        username = StringSubstr(username, 0, 20);
    
    return(username);
}

//+------------------------------------------------------------------+
//| Получение текущей даты и времени - ИНТЕГРАЦИЯ                   |
//+------------------------------------------------------------------+
string GetCurrentDateTime()
{
    // ИНТЕГРАЦИЯ: Используем базовое время и прибавляем runtime
    datetime base_time = StringToTime(SYSTEM_UTC_TIME);
    datetime current_time = TimeGMT();
    
    // Если системное время позже базового, используем его
    if(current_time > base_time)
    {
        MqlDateTime dt;
        TimeToStruct(current_time, dt);
        return(StringFormat("%04d-%02d-%02d %02d:%02d:%02d", 
                           dt.year, dt.mon, dt.day, dt.hour, dt.min, dt.sec));
    }
    else
    {
        // Используем интегрированное время
        return(SYSTEM_UTC_TIME);
    }
}

//+------------------------------------------------------------------+
//| Получение времени работы сессии                                 |
//+------------------------------------------------------------------+
string GetSessionUptime()
{
    if(session_start_time == 0)
        return "00:00";
    
    datetime current_time = TimeGMT();
    int uptime_seconds = (int)(current_time - session_start_time);
    
    int days = uptime_seconds / 86400;
    uptime_seconds %= 86400;
    int hours = uptime_seconds / 3600;
    uptime_seconds %= 3600;
    int minutes = uptime_seconds / 60;
    
    string uptime_str = "";
    
    if(days > 0)
        uptime_str += IntegerToString(days) + GetLocalizedText("days") + " ";
    if(hours > 0)
        uptime_str += IntegerToString(hours) + GetLocalizedText("hours") + " ";
    
    uptime_str += IntegerToString(minutes) + GetLocalizedText("minutes");
    
    return uptime_str;
}

//+------------------------------------------------------------------+
//| Send Alert Function                                              |
//+------------------------------------------------------------------+
void SendAlert(AlertType alert_type, string message, int bar_index = 0)
{
    if(!EnableAlerts) return;
    
    // Check if enough time has passed since last alert of this type (spam protection)
    datetime current_time = TimeCurrent();
    if(current_time - last_alert_time[alert_type] < 60) // 1 minute minimum between same type alerts
        return;
    
    // Prevent duplicate alerts on the same bar (candle)
    if(last_alert_bar[alert_type] == bar_index && bar_index > 0)
        return;
    
    last_alert_time[alert_type] = current_time;
    last_alert_bar[alert_type] = bar_index;
    
    // ИНТЕГРАЦИЯ: Добавляем информацию о пользователе в алерт
    string full_message = "[" + SYSTEM_USER + "] " + Symbol() + " - " + message;
    
    // Show popup alert
    if(ShowPopupAlerts)
    {
        Alert(full_message);
    }
    
    // Play sound
    if(PlaySoundAlerts && StringLen(AlertSoundFile) > 0)
    {
        PlaySound(AlertSoundFile);
    }
    
    // Send push notification
    if(SendPushAlerts)
    {
        SendNotification(full_message);
    }
    
    // Print to log with enhanced information
    string log_time = GetCurrentDateTime();
    Print("🔔 ALERT [", log_time, "] [", SYSTEM_USER, "]: ", full_message);
}

//+------------------------------------------------------------------+
//| Calculate Dynamic Zones - ИСПРАВЛЕНО                            |
//+------------------------------------------------------------------+
void CalculateDynamicZones(int current_bar)
{
    if(!ShowAutoZones || current_bar < ZoneCalculationPeriod)
        return;
    
    // Collect VFI values for zone calculation
    double vfi_values[];
    ArrayResize(vfi_values, ZoneCalculationPeriod);
    
    int count = 0;
    for(int i = current_bar - ZoneCalculationPeriod + 1; i <= current_bar && count < ZoneCalculationPeriod; i++)
    {
        if(i >= 0 && i < ArraySize(VFI_Buffer) && VFI_Buffer[i] != EMPTY_VALUE)
        {
            vfi_values[count] = VFI_Buffer[i];
            count++;
        }
    }
    
    if(count < ZoneCalculationPeriod / 2)
        return;
    
    // ИСПРАВЛЕНИЕ: Изменяем размер массива под реальное количество элементов
    ArrayResize(vfi_values, count);
    
    // ИСПРАВЛЕНИЕ: Сортируем массив правильно - только один параметр
    ArraySort(vfi_values);
    
    // Calculate percentile positions
    int upper_pos = (int)((count - 1) * ZonePercentile / 100.0);
    int lower_pos = (int)((count - 1) * (100.0 - ZonePercentile) / 100.0);
    
    // Проверяем корректность индексов
    if(upper_pos >= count) upper_pos = count - 1;
    if(lower_pos < 0) lower_pos = 0;
    if(upper_pos < 0) upper_pos = 0;
    if(lower_pos >= count) lower_pos = count - 1;
    
    // Update dynamic levels
    dynamic_overbought_level = vfi_values[upper_pos];
    dynamic_oversold_level = vfi_values[lower_pos];
    
    // Дополнительная проверка: убеждаемся что overbought > oversold
    if(dynamic_overbought_level <= dynamic_oversold_level)
    {
        // Если что-то пошло не так, используем разумные значения по умолчанию
        double avg_abs = 0;
        for(int i = 0; i < count; i++)
        {
            avg_abs += MathAbs(vfi_values[i]);
        }
        avg_abs /= count;
        
        dynamic_overbought_level = avg_abs * 1.5;
        dynamic_oversold_level = -avg_abs * 1.5;
    }
    
    // Create zone objects
    CreateZoneObjects(current_bar);
}

//+------------------------------------------------------------------+
//| Create Zone Objects - УЛУЧШЕНО                                  |
//+------------------------------------------------------------------+
void CreateZoneObjects(int current_bar)
{
    string overbought_name = "VFI_Overbought_Zone";
    string oversold_name = "VFI_Oversold_Zone";
    
    // Remove existing zones
    ObjectDelete(0, overbought_name);
    ObjectDelete(0, oversold_name);
    
    if(!ShowAutoZones)
        return;
    
    // Получаем окно индикатора
    int window = ChartWindowFind();
    if(window < 0) return; // Если окно не найдено
    
    datetime time_start = iTime(Symbol(), PERIOD_CURRENT, MathMin(current_bar, 100));
    datetime time_end = iTime(Symbol(), PERIOD_CURRENT, 0);
    
    // Проверяем валидность времени
    if(time_start <= 0 || time_end <= 0) return;
    
    // Create overbought zone rectangle
    if(ObjectCreate(0, overbought_name, OBJ_RECTANGLE, window, 
                   time_start, dynamic_overbought_level, time_end, dynamic_overbought_level + MathAbs(dynamic_overbought_level)))
    {
        ObjectSetInteger(0, overbought_name, OBJPROP_COLOR, OverboughtZoneColor);
        ObjectSetInteger(0, overbought_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, overbought_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, overbought_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, overbought_name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, overbought_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, overbought_name, OBJPROP_WIDTH, 1);
        
        // ИСПРАВЛЕНИЕ: Правильная установка прозрачности
        ObjectSetInteger(0, overbought_name, OBJPROP_BGCOLOR, OverboughtZoneColor);
    }
    
    // Create oversold zone rectangle  
    if(ObjectCreate(0, oversold_name, OBJ_RECTANGLE, window, 
                   time_start, dynamic_oversold_level - MathAbs(dynamic_oversold_level), time_end, dynamic_oversold_level))
    {
        ObjectSetInteger(0, oversold_name, OBJPROP_COLOR, OversoldZoneColor);
        ObjectSetInteger(0, oversold_name, OBJPROP_FILL, true);
        ObjectSetInteger(0, oversold_name, OBJPROP_BACK, true);
        ObjectSetInteger(0, oversold_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, oversold_name, OBJPROP_HIDDEN, true);
        ObjectSetInteger(0, oversold_name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, oversold_name, OBJPROP_WIDTH, 1);
        
        // ИСПРАВЛЕНИЕ: Правильная установка прозрачности
        ObjectSetInteger(0, oversold_name, OBJPROP_BGCOLOR, OversoldZoneColor);
    }
}

//+------------------------------------------------------------------+
//| Find Local Peaks and Troughs - ИСПРАВЛЕНО                     |
//+------------------------------------------------------------------+
bool IsLocalMaximum(const double &buffer[], int pos, int lookback = 5)
{
    if(pos < lookback || pos >= ArraySize(buffer) - lookback)
        return false;
    
    if(pos < 0 || pos >= ArraySize(buffer))
        return false;
    
    double current = buffer[pos];
    if(current == EMPTY_VALUE)
        return false;
    
    for(int i = 1; i <= lookback; i++)
    {
        if(pos - i < 0 || pos + i >= ArraySize(buffer))
            continue;
            
        if(buffer[pos - i] == EMPTY_VALUE || buffer[pos + i] == EMPTY_VALUE)
            continue;
            
        if(buffer[pos - i] >= current || buffer[pos + i] >= current)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Find Local Minimum - ИСПРАВЛЕНО                                |
//+------------------------------------------------------------------+
bool IsLocalMinimum(const double &buffer[], int pos, int lookback = 5)
{
    if(pos < lookback || pos >= ArraySize(buffer) - lookback)
        return false;
    
    if(pos < 0 || pos >= ArraySize(buffer))
        return false;
    
    double current = buffer[pos];
    if(current == EMPTY_VALUE)
        return false;
    
    for(int i = 1; i <= lookback; i++)
    {
        if(pos - i < 0 || pos + i >= ArraySize(buffer))
            continue;
            
        if(buffer[pos - i] == EMPTY_VALUE || buffer[pos + i] == EMPTY_VALUE)
            continue;
            
        if(buffer[pos - i] <= current || buffer[pos + i] <= current)
            return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Detect Divergences                                              |
//+------------------------------------------------------------------+
void DetectDivergences(const double &close[], int current_bar)
{
    if(!DetectDivergences || current_bar < DivergenceBars)
        return;
    
    static int last_divergence_bar = -1;
    if(current_bar - last_divergence_bar < MinDivergenceDistance)
        return;
    
    // Find recent peaks and troughs in both price and VFI
    int vfi_peak1 = -1, vfi_peak2 = -1;
    int vfi_trough1 = -1, vfi_trough2 = -1;
    int price_peak1 = -1, price_peak2 = -1;
    int price_trough1 = -1, price_trough2 = -1;
    
    // Search for VFI peaks and troughs
    for(int i = current_bar - 5; i >= current_bar - DivergenceBars && i >= 5; i--)
    {
        if(IsLocalMaximum(VFI_Buffer, i))
        {
            if(vfi_peak1 == -1)
                vfi_peak1 = i;
            else if(vfi_peak2 == -1 && i < vfi_peak1 - MinDivergenceDistance)
            {
                vfi_peak2 = i;
                break;
            }
        }
    }
    
    for(int i = current_bar - 5; i >= current_bar - DivergenceBars && i >= 5; i--)
    {
        if(IsLocalMinimum(VFI_Buffer, i))
        {
            if(vfi_trough1 == -1)
                vfi_trough1 = i;
            else if(vfi_trough2 == -1 && i < vfi_trough1 - MinDivergenceDistance)
            {
                vfi_trough2 = i;
                break;
            }
        }
    }
    
    // Search for price peaks and troughs
    for(int i = current_bar - 5; i >= current_bar - DivergenceBars && i >= 5; i--)
    {
        if(IsLocalMaximum(close, i))
        {
            if(price_peak1 == -1)
                price_peak1 = i;
            else if(price_peak2 == -1 && i < price_peak1 - MinDivergenceDistance)
            {
                price_peak2 = i;
                break;
            }
        }
    }
    
    for(int i = current_bar - 5; i >= current_bar - DivergenceBars && i >= 5; i--)
    {
        if(IsLocalMinimum(close, i))
        {
            if(price_trough1 == -1)
                price_trough1 = i;
            else if(price_trough2 == -1 && i < price_trough1 - MinDivergenceDistance)
            {
                price_trough2 = i;
                break;
            }
        }
    }
    
    // Check for bearish divergence (price makes higher high, VFI makes lower high)
    if(vfi_peak1 != -1 && vfi_peak2 != -1 && price_peak1 != -1 && price_peak2 != -1)
    {
        if(close[price_peak1] > close[price_peak2] && VFI_Buffer[vfi_peak1] < VFI_Buffer[vfi_peak2])
        {
            // Bearish divergence detected
            if(ShowDivergenceLines)
            {
                DrawDivergenceLine("BearishDiv_" + IntegerToString(current_bar), 
                                 price_peak2, price_peak1, BearishDivergenceColor, false);
            }
            
            if(AlertOnDivergence)
            {
                SendAlert(ALERT_BEARISH_DIV, GetLocalizedText("bearish_divergence"), current_bar);
            }
            
            last_divergence_bar = current_bar;
        }
    }
    
    // Check for bullish divergence (price makes lower low, VFI makes higher low)
    if(vfi_trough1 != -1 && vfi_trough2 != -1 && price_trough1 != -1 && price_trough2 != -1)
    {
        if(close[price_trough1] < close[price_trough2] && VFI_Buffer[vfi_trough1] > VFI_Buffer[vfi_trough2])
        {
            // Bullish divergence detected
            if(ShowDivergenceLines)
            {
                DrawDivergenceLine("BullishDiv_" + IntegerToString(current_bar), 
                                 price_trough2, price_trough1, BullishDivergenceColor, true);
            }
            
            if(AlertOnDivergence)
            {
                SendAlert(ALERT_BULLISH_DIV, GetLocalizedText("bullish_divergence"), current_bar);
            }
            
            last_divergence_bar = current_bar;
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Divergence Line - ИСПРАВЛЕНО                              |
//+------------------------------------------------------------------+
void DrawDivergenceLine(string name, int bar1, int bar2, color line_color, bool is_bullish)
{
    ObjectDelete(0, name);
    
    // Проверяем валидность параметров
    if(bar1 < 0 || bar2 < 0 || bar1 >= ArraySize(VFI_Buffer) || bar2 >= ArraySize(VFI_Buffer))
        return;
    
    if(VFI_Buffer[bar1] == EMPTY_VALUE || VFI_Buffer[bar2] == EMPTY_VALUE)
        return;
    
    datetime time1 = iTime(Symbol(), PERIOD_CURRENT, bar1);
    datetime time2 = iTime(Symbol(), PERIOD_CURRENT, bar2);
    
    if(time1 <= 0 || time2 <= 0) return;
    
    double price1 = VFI_Buffer[bar1];
    double price2 = VFI_Buffer[bar2];
    
    int window = ChartWindowFind();
    if(window < 0) return;
    
    if(ObjectCreate(0, name, OBJ_TREND, window, time1, price1, time2, price2))
    {
        ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, DivergenceLineWidth);
        ObjectSetInteger(0, name, OBJPROP_STYLE, is_bullish ? STYLE_SOLID : STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
    }
}

//+------------------------------------------------------------------+
//| Update Info Panel - РАСШИРЕННАЯ ВЕРСИЯ                         |
//+------------------------------------------------------------------+
void UpdateInfoPanel(int current_bar)
{
    if(!ShowInfoPanel)
    {
        ObjectDelete(0, panel_name);
        return;
    }
    
    if(current_bar < 1 || VFI_Buffer[current_bar] == EMPTY_VALUE)
        return;
    
    // Get current values
    double current_vfi = VFI_Buffer[current_bar];
    double current_ema = VFI_EMA_Buffer[current_bar];
    
    // Determine trend status
    string trend_status = GetLocalizedText("neutral");
    if(current_vfi > current_ema && current_vfi > 0)
        trend_status = GetLocalizedText("bullish");
    else if(current_vfi < current_ema && current_vfi < 0)
        trend_status = GetLocalizedText("bearish");
    
    // Determine signal strength
    string signal_strength = GetLocalizedText("weak");
    double vfi_abs = MathAbs(current_vfi);
    if(ShowAutoZones && dynamic_overbought_level != 0)
    {
        if(vfi_abs > MathAbs(dynamic_overbought_level) * 0.8)
            signal_strength = GetLocalizedText("strong");
        else if(vfi_abs > MathAbs(dynamic_overbought_level) * 0.4)
            signal_strength = GetLocalizedText("medium");
    }
    
    // Determine last signal
    string last_signal = GetLocalizedText("none");
    if(current_bar > 0)
    {
        if(BuyArrow_Buffer[current_bar] != EMPTY_VALUE)
            last_signal = GetLocalizedText("buy_signal");
        else if(SellArrow_Buffer[current_bar] != EMPTY_VALUE)
            last_signal = GetLocalizedText("sell_signal");
        else
        {
            // Check previous bars
            for(int i = current_bar - 1; i >= MathMax(0, current_bar - 10); i--)
            {
                if(BuyArrow_Buffer[i] != EMPTY_VALUE)
                {
                    last_signal = GetLocalizedText("buy_signal");
                    break;
                }
                else if(SellArrow_Buffer[i] != EMPTY_VALUE)
                {
                    last_signal = GetLocalizedText("sell_signal");
                    break;
                }
            }
        }
    }
    
    // ИНТЕГРАЦИЯ: Расширенная информационная панель
    string panel_text = "";
    panel_text += "═══ VFI ENHANCED [" + SYSTEM_USER + "] ═══\n";
    panel_text += GetLocalizedText("current_vfi") + ": " + DoubleToString(current_vfi, 2) + "\n";
    panel_text += GetLocalizedText("trend_status") + ": " + trend_status + "\n";
    panel_text += GetLocalizedText("signal_strength") + ": " + signal_strength + "\n";
    panel_text += GetLocalizedText("last_signal") + ": " + last_signal + "\n";
    panel_text += "───────────────────────────\n";
    if(ShowAutoZones)
    {
        panel_text += "OB: " + DoubleToString(dynamic_overbought_level, 2) + "\n";
        panel_text += "OS: " + DoubleToString(dynamic_oversold_level, 2) + "\n";
        panel_text += "───────────────────────────\n";
    }
    panel_text += GetLocalizedText("session_stats") + ":\n";
    panel_text += GetLocalizedText("buy_signals") + ": " + IntegerToString(total_signals_buy) + "\n";
    panel_text += GetLocalizedText("sell_signals") + ": " + IntegerToString(total_signals_sell) + "\n";
    panel_text += GetLocalizedText("total_signals") + ": " + IntegerToString(total_signals_buy + total_signals_sell) + "\n";
    panel_text += GetLocalizedText("uptime") + ": " + GetSessionUptime();
    
    // Remove existing panel
    ObjectDelete(0, panel_name);
    
    // Create new panel
    if(ObjectCreate(0, panel_name, OBJ_LABEL, ChartWindowFind(), 0, 0))
    {
        ObjectSetString(0, panel_name, OBJPROP_TEXT, panel_text);
        ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, PanelX);
        ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, PanelY);
        ObjectSetInteger(0, panel_name, OBJPROP_COLOR, TextColor);
        ObjectSetInteger(0, panel_name, OBJPROP_FONTSIZE, FontSize);
        ObjectSetString(0, panel_name, OBJPROP_FONT, "Courier New");
        ObjectSetInteger(0, panel_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, panel_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, panel_name, OBJPROP_HIDDEN, true);
    }
}

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // ИНТЕГРАЦИЯ: Установка времени начала сессии
    session_start_time = TimeGMT();
    total_signals_buy = 0;
    total_signals_sell = 0;
    
    // Validate input parameters
    if(VFI_Length < 10)
    {
        Print("❌ ", GetLocalizedText("parameter_error"), ": ", GetLocalizedText("invalid_vfi_length"));
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    if(SignalLength < 1)
    {
        Print("❌ ", GetLocalizedText("parameter_error"), ": ", GetLocalizedText("invalid_signal_length"));
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    if(Coef <= 0 || VCoef <= 0)
    {
        Print("❌ ", GetLocalizedText("parameter_error"), ": ", GetLocalizedText("invalid_coefficients"));
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    // Determine system language
    is_russian_system = IsRussianSystem();
    
    // Initialize alert times
    ArrayInitialize(last_alert_time, 0);
    ArrayInitialize(last_alert_bar, -1);
    
    // Reset calculation counter
    last_calculated = 0;
    
    //--- indicator buffers mapping
    SetIndexBuffer(0, VFI_Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, VFI_EMA_Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, Histogram_Buffer, INDICATOR_DATA);
    SetIndexBuffer(3, VCP_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(4, BuyArrow_Buffer, INDICATOR_DATA);
    SetIndexBuffer(5, SellArrow_Buffer, INDICATOR_DATA);
    SetIndexBuffer(6, UpperZone_Buffer, INDICATOR_CALCULATIONS);
    SetIndexBuffer(7, LowerZone_Buffer, INDICATOR_CALCULATIONS);
    
    //--- set arrow codes
    PlotIndexSetInteger(3, PLOT_ARROW, 233); // Up arrow for buy signals
    PlotIndexSetInteger(4, PLOT_ARROW, 234); // Down arrow for sell signals
    
    //--- set accuracy
    IndicatorSetInteger(INDICATOR_DIGITS, 4);
    
    //--- set short name
    IndicatorSetString(INDICATOR_SHORTNAME, "VFI_Enhanced(" + 
                      IntegerToString(VFI_Length) + "," + 
                      DoubleToString(Coef, 1) + "," + 
                      DoubleToString(VCoef, 1) + ")");
    
    //--- set zero level
    IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 0.0);
    
    //--- set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    //--- hide histogram if not needed
    if(!ShowHisto)
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
    else
        PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
    
    //--- hide arrows if not needed
    if(!ShowArrows)
    {
        PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
        PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
    }
    else
    {
        PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_ARROW);
        PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_ARROW);
    }
    
    //--- set arrow colors
    PlotIndexSetInteger(3, PLOT_LINE_COLOR, BuyArrowColor);
    PlotIndexSetInteger(4, PLOT_LINE_COLOR, SellArrowColor);
    PlotIndexSetInteger(3, PLOT_LINE_WIDTH, ArrowSize);
    PlotIndexSetInteger(4, PLOT_LINE_WIDTH, ArrowSize);
    
    //--- initialize calculation arrays
    ArrayResize(inter_array, 0);
    ArrayResize(typical_array, 0);
    
    //--- check volume data
    CheckVolumeData();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Проверка наличия и качества данных - ИНТЕГРАЦИЯ                 |
//+------------------------------------------------------------------+
void CheckVolumeData()
{
    string symbol = Symbol();
    string username = GetComputerUserName(); // Использует интегрированные данные
    string current_datetime = GetCurrentDateTime(); // Использует интегрированное время
    
    Print("╔══════════════════════════════════════════════════════════════════╗");
    Print("║", GetLocalizedText("volume_check_header"), "║");
    Print("╠══════════════════════════════════════════════════════════════════╣");
    Print("║ ", GetLocalizedText("symbol"), ": ", symbol);
    Print("║ ", GetLocalizedText("datetime"), ": ", current_datetime, " UTC");
    Print("║ ", GetLocalizedText("user"), ": ", username, " (Integrated)"); // Помечаем как интегрированный
    Print("║ ", GetLocalizedText("session_started"), ": ", TimeToString(session_start_time, TIME_DATE|TIME_MINUTES));
    Print("╠══════════════════════════════════════════════════════════════════╣");
    
    // Debug terminal paths
    Print("║ ", GetLocalizedText("terminal_paths"), ":");
    Print("║   TERMINAL_PATH: ", TerminalInfoString(TERMINAL_PATH));
    Print("║   TERMINAL_DATA_PATH: ", TerminalInfoString(TERMINAL_DATA_PATH));
    Print("║   TERMINAL_COMMONDATA_PATH: ", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
    Print("╠══════════════════════════════════════════════════════════════════╣");
    
    // Check execution type
    ENUM_SYMBOL_TRADE_EXECUTION execution = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
    string exec_type = "";
    switch(execution)
    {
        case SYMBOL_TRADE_EXECUTION_REQUEST: exec_type = "Request"; break;
        case SYMBOL_TRADE_EXECUTION_INSTANT: exec_type = "Instant"; break;
        case SYMBOL_TRADE_EXECUTION_MARKET: exec_type = "Market"; break;
        case SYMBOL_TRADE_EXECUTION_EXCHANGE: exec_type = "Exchange"; break;
        default: exec_type = "Unknown";
    }
    Print("║ ", GetLocalizedText("execution_type"), ": ", exec_type);
    
    // Get test data
    MqlRates rates[];
    int copied = CopyRates(symbol, PERIOD_CURRENT, 0, 100, rates);
    
    if(copied <= 0)
    {
        Print("║ ", GetLocalizedText("error_no_data"));
        Print("╚══════════════════════════════════════════════════════════════════╝");
        return;
    }
    
    Print("║ ", GetLocalizedText("bars_analyzed"), ": ", copied);
    Print("╠══════════════════════════════════════════════════════════════════╣");
    
    // Analyze tick volumes
    long total_tick_volume = 0;
    long max_tick_volume = 0;
    long min_tick_volume = LONG_MAX;
    int zero_tick_volumes = 0;
    
    // Analyze real volumes
    long total_real_volume = 0;
    long max_real_volume = 0;
    long min_real_volume = LONG_MAX;
    int zero_real_volumes = 0;
    bool has_real_volumes = false;
    
    for(int i = 0; i < copied; i++)
    {
        // Tick volumes
        if(rates[i].tick_volume == 0)
            zero_tick_volumes++;
        
        total_tick_volume += rates[i].tick_volume;
        
        if(rates[i].tick_volume > max_tick_volume)
            max_tick_volume = rates[i].tick_volume;
            
        if(rates[i].tick_volume < min_tick_volume && rates[i].tick_volume > 0)
            min_tick_volume = rates[i].tick_volume;
        
        // Real volumes
        if(rates[i].real_volume > 0)
        {
            has_real_volumes = true;
            total_real_volume += rates[i].real_volume;
            
            if(rates[i].real_volume > max_real_volume)
                max_real_volume = rates[i].real_volume;
                
            if(rates[i].real_volume < min_real_volume)
                min_real_volume = rates[i].real_volume;
        }
        else
        {
            zero_real_volumes++;
        }
    }
    
    // Tick volume results
    double avg_tick_volume = (double)total_tick_volume / copied;
    Print("║ ", GetLocalizedText("tick_volumes"), ":");
    Print("║   ", GetLocalizedText("average"), ": ", (long)avg_tick_volume);
    Print("║   ", GetLocalizedText("maximum"), ": ", max_tick_volume);
    Print("║   ", GetLocalizedText("minimum"), ": ", min_tick_volume);
    Print("║   ", GetLocalizedText("zero_bars"), ": ", zero_tick_volumes, " (", 
          MathRound(zero_tick_volumes * 100.0 / copied), "%)");
    
    // Real volume results
    real_volumes_available = has_real_volumes;
    if(has_real_volumes)
    {
        double avg_real_volume = (double)total_real_volume / (copied - zero_real_volumes);
        Print("║ ", GetLocalizedText("real_volumes"), ":");
        Print("║   ", GetLocalizedText("average"), ": ", (long)avg_real_volume);
        Print("║   ", GetLocalizedText("maximum"), ": ", max_real_volume);
        Print("║   ", GetLocalizedText("minimum"), ": ", min_real_volume);
        Print("║   ", GetLocalizedText("zero_bars"), ": ", zero_real_volumes, " (", 
              MathRound(zero_real_volumes * 100.0 / copied), "%)");
    }
    else
    {
        Print("║ ", GetLocalizedText("real_volumes_unavailable"));
    }
    
    Print("╠══════════════════════════════════════════════════════════════════╣");
    
    // Data quality assessment
    string quality_assessment = "";
    string recommendation = "";
    
    if(!has_real_volumes && zero_tick_volumes > copied * 0.5)
    {
        quality_assessment = GetLocalizedText("critical_no_volumes");
        recommendation = GetLocalizedText("change_instrument");
    }
    else if(!has_real_volumes && (max_tick_volume - min_tick_volume) < avg_tick_volume * 0.1)
    {
        quality_assessment = GetLocalizedText("poor_no_variation");
        recommendation = GetLocalizedText("may_work_incorrectly");
    }
    else if(!has_real_volumes)
    {
        quality_assessment = GetLocalizedText("satisfactory_tick_only");
        recommendation = GetLocalizedText("will_work_less_accurate");
    }
    else if(has_real_volumes && zero_real_volumes < copied * 0.1)
    {
        quality_assessment = GetLocalizedText("excellent_real_volumes");
        recommendation = GetLocalizedText("will_work_max_accurate");
    }
    else
    {
        quality_assessment = GetLocalizedText("good_real_gaps");
        recommendation = GetLocalizedText("will_work_correctly");
    }
    
    Print("║ ", GetLocalizedText("quality_assessment"), ": ", quality_assessment);
    Print("║ ", GetLocalizedText("recommendation"), ": ", recommendation);
    
    // Enhanced indicator settings
    Print("╠══════════════════════════════════════════════════════════════════╣");
    Print("║ ", GetLocalizedText("indicator_settings"), ":");
    
    if(has_real_volumes && UseRealVolume)
    {
        Print("║   ", GetLocalizedText("will_use_real"));
    }
    else
    {
        Print("║   ", GetLocalizedText("will_use_tick"));
    }
    
    Print("║   VFI Length: ", VFI_Length);
    Print("║   Coefficient: ", Coef);
    Print("║   Max Volume Cutoff: ", VCoef);
    Print("║   Signal Length: ", SignalLength);
    Print("║   Smooth VFI: ", SmoothVFI ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Show Histogram: ", ShowHisto ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Enable Alerts: ", EnableAlerts ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Show Arrows: ", ShowArrows ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Auto Zones: ", ShowAutoZones ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Detect Divergences: ", DetectDivergences ? GetLocalizedText("yes") : GetLocalizedText("no"));
    Print("║   Info Panel: ", ShowInfoPanel ? GetLocalizedText("yes") : GetLocalizedText("no"));
    
    Print("╚══════════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Minimum bars needed for calculation
    int min_bars = VFI_Length + 50;
    if(rates_total < min_bars)
        return(0);
    
    // Check if recalculation is needed
    bool recalculate_all = false;
    if(prev_calculated == 0 || last_calculated > prev_calculated)
    {
        recalculate_all = true;
        last_calculated = 0;
        
        Print("ℹ️ ", GetLocalizedText("settings_changed"));
        
        // Initialize buffers
        ArrayInitialize(VFI_Buffer, EMPTY_VALUE);
        ArrayInitialize(VFI_EMA_Buffer, EMPTY_VALUE);
        ArrayInitialize(Histogram_Buffer, EMPTY_VALUE);
        ArrayInitialize(VCP_Buffer, 0.0);
        ArrayInitialize(BuyArrow_Buffer, EMPTY_VALUE);
        ArrayInitialize(SellArrow_Buffer, EMPTY_VALUE);
        ArrayInitialize(UpperZone_Buffer, EMPTY_VALUE);
        ArrayInitialize(LowerZone_Buffer, EMPTY_VALUE);
    }
    
        //--- resize calculation arrays
    if(ArraySize(inter_array) != rates_total || recalculate_all)
    {
        ArrayResize(inter_array, rates_total);
        ArrayResize(typical_array, rates_total);
        ArrayInitialize(inter_array, 0.0);
        ArrayInitialize(typical_array, 0.0);
    }
    
    // Determine start position for calculation
    int start;
    if(recalculate_all)
    {
        start = min_bars;
    }
    else
    {
        start = MathMax(prev_calculated - 1, min_bars);
    }
    
    //--- calculate typical prices and inter values from the beginning
    int calc_start = recalculate_all ? 1 : MathMax(1, start - 100);
    
    for(int i = calc_start; i < rates_total; i++)
    {
        // Check price validity
        if(high[i] <= 0 || low[i] <= 0 || close[i] <= 0)
        {
            typical_array[i] = i > 0 ? typical_array[i-1] : close[i];
        }
        else
        {
            typical_array[i] = (high[i] + low[i] + close[i]) / 3.0;
        }
        
        if(i > 0 && typical_array[i-1] > 0 && typical_array[i] > 0)
        {
            double log_diff = MathLog(typical_array[i]) - MathLog(typical_array[i-1]);
            // Limit extreme values
            if(MathAbs(log_diff) > 1.0)
                log_diff = log_diff > 0 ? 1.0 : -1.0;
            inter_array[i] = log_diff;
        }
        else
        {
            inter_array[i] = 0.0;
        }
    }
    
    //--- main calculation loop
    for(int i = start; i < rates_total; i++)
    {
        //--- calculate vinter (standard deviation of inter over 30 periods)
        double vinter = CalculateStdDev(i, MathMin(30, i));
        
        // Protection from too small values
        if(vinter < 0.0001)
            vinter = 0.0001;
        
        //--- calculate cutoff
        double cutoff = Coef * vinter * close[i];
        
        //--- calculate volume average over VFI_Length periods
        double vave = 0.0;
        int vol_start = MathMax(0, i - VFI_Length);
        int vol_count = 0;
        
        // Determine which volumes to use
        bool use_real = UseRealVolume && real_volumes_available;
        
        for(int j = vol_start; j < i && j < ArraySize(tick_volume) && j < ArraySize(volume); j++)
        {
            long vol_value = use_real ? volume[j] : tick_volume[j];
            if(vol_value > 0) // Exclude zero volumes
            {
                vave += (double)vol_value;
                vol_count++;
            }
        }
        
        // Protection from division by zero
        if(vol_count > 0)
            vave /= (double)vol_count;
        else
            vave = use_real ? (double)volume[i] : (double)tick_volume[i];
            
        if(vave <= 0)
            vave = 1.0; // Minimum value
        
        //--- calculate vmax
        double vmax = vave * VCoef;
        
        //--- calculate vc (min of current volume and vmax)
        long vol_current = 0;
        if(i < ArraySize(volume) && i < ArraySize(tick_volume))
        {
            vol_current = use_real ? volume[i] : tick_volume[i];
        }
        if(vol_current <= 0)
            vol_current = (long)vave; // Use average value
            
        double vc = MathMin((double)vol_current, vmax);
        
        //--- calculate mf (money flow)
        double mf = 0.0;
        if(i > 0)
            mf = typical_array[i] - typical_array[i-1];
        
        //--- calculate vcp
        double vcp = 0.0;
        if(mf > cutoff)
            vcp = vc;
        else if(mf < -cutoff)
            vcp = -vc;
        else
            vcp = 0.0;
        
        VCP_Buffer[i] = vcp;
        
        //--- calculate VFI (sum of vcp over VFI_Length periods divided by vave)
        double vcp_sum = 0.0;
        int vcp_start = MathMax(0, i - VFI_Length + 1);
        for(int j = vcp_start; j <= i; j++)
        {
            vcp_sum += VCP_Buffer[j];
        }
        
        // Additional protection from large values
        double vfi_raw = vcp_sum / vave;
        if(MathAbs(vfi_raw) > 1000) // Limit maximum value
            vfi_raw = vfi_raw > 0 ? 1000 : -1000;
        
        //--- apply smoothing if needed (SMA with period 3)
        if(SmoothVFI && i >= start + 2)
        {
            double vfi_sum = vfi_raw;
            int count = 1;
            
            for(int j = 1; j <= 2 && (i-j) >= start; j++)
            {
                if(VFI_Buffer[i-j] != EMPTY_VALUE)
                {
                    vfi_sum += VFI_Buffer[i-j];
                    count++;
                }
            }
            
            VFI_Buffer[i] = vfi_sum / count;
        }
        else
        {
            VFI_Buffer[i] = vfi_raw;
        }
        
        //--- calculate VFI EMA
        if(i == start || VFI_EMA_Buffer[i-1] == EMPTY_VALUE)
        {
            VFI_EMA_Buffer[i] = VFI_Buffer[i];
        }
        else
        {
            double alpha = 2.0 / (SignalLength + 1.0);
            VFI_EMA_Buffer[i] = alpha * VFI_Buffer[i] + (1.0 - alpha) * VFI_EMA_Buffer[i-1];
        }
        
        //--- calculate histogram
        if(ShowHisto)
            Histogram_Buffer[i] = VFI_Buffer[i] - VFI_EMA_Buffer[i];
        else
            Histogram_Buffer[i] = EMPTY_VALUE;
        
        //--- Initialize signal arrows
        BuyArrow_Buffer[i] = EMPTY_VALUE;
        SellArrow_Buffer[i] = EMPTY_VALUE;
        
        //--- Generate signals and alerts (only for recent bars to avoid spam)
        if(i >= rates_total - 10)
        {
            // Calculate dynamic zones
            CalculateDynamicZones(i);
            
            // Check for signals and alerts
            CheckSignalsAndAlerts(i, close);
            
            // Detect divergences
            DetectDivergences(close, i);
            
            // Update info panel
            if(i == rates_total - 1)
                UpdateInfoPanel(i);
        }
    }
    
    last_calculated = rates_total;
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check Signals and Alerts - ОБНОВЛЕНО                           |
//+------------------------------------------------------------------+
void CheckSignalsAndAlerts(int current_bar, const double &close[])
{
    if(current_bar < 2 || current_bar >= ArraySize(VFI_Buffer) || current_bar >= ArraySize(VFI_EMA_Buffer))
        return;
    
    double current_vfi = VFI_Buffer[current_bar];
    double prev_vfi = VFI_Buffer[current_bar - 1];
    double current_ema = VFI_EMA_Buffer[current_bar];
    double prev_ema = VFI_EMA_Buffer[current_bar - 1];
    
    if(current_vfi == EMPTY_VALUE || prev_vfi == EMPTY_VALUE || 
       current_ema == EMPTY_VALUE || prev_ema == EMPTY_VALUE)
        return;
    
    // Check EMA Crossings (Primary signals - VFI crosses EMA)
    if(AlertOnEMACross)
    {
        // VFI crosses above EMA (BUY signal)
        if(prev_vfi <= prev_ema && current_vfi > current_ema)
        {
            if(ShowArrows && current_bar < ArraySize(BuyArrow_Buffer))
            {
                BuyArrow_Buffer[current_bar] = MathMin(current_vfi, current_ema) - MathAbs(current_vfi - current_ema) * 0.1;
                total_signals_buy++; // ИНТЕГРАЦИЯ: Подсчет сигналов
            }
            SendAlert(ALERT_EMA_CROSS_UP, GetLocalizedText("vfi_ema_cross_up"), current_bar);
        }
        // VFI crosses below EMA (SELL signal)
        else if(prev_vfi >= prev_ema && current_vfi < current_ema)
        {
            if(ShowArrows && current_bar < ArraySize(SellArrow_Buffer))
            {
                SellArrow_Buffer[current_bar] = MathMax(current_vfi, current_ema) + MathAbs(current_vfi - current_ema) * 0.1;
                total_signals_sell++; // ИНТЕГРАЦИЯ: Подсчет сигналов
            }
            SendAlert(ALERT_EMA_CROSS_DOWN, GetLocalizedText("vfi_ema_cross_down"), current_bar);
        }
    }
    
    // Check Zero Line Crossings (Secondary alerts only, no signal arrows)
    if(AlertOnZeroCross && !AlertOnEMACross) // Only if EMA cross alerts are disabled
    {
        // VFI crosses above zero line
        if(prev_vfi <= 0 && current_vfi > 0)
        {
            SendAlert(ALERT_ZERO_CROSS_UP, GetLocalizedText("vfi_cross_up"), current_bar);
        }
        // VFI crosses below zero line
        else if(prev_vfi >= 0 && current_vfi < 0)
        {
            SendAlert(ALERT_ZERO_CROSS_DOWN, GetLocalizedText("vfi_cross_down"), current_bar);
        }
    }
    
    // Check Zone Entries
    if(AlertOnZones && ShowAutoZones && dynamic_overbought_level != 0 && dynamic_oversold_level != 0)
    {
        // Entering overbought zone
        if(prev_vfi < dynamic_overbought_level && current_vfi >= dynamic_overbought_level)
        {
            if(ShowArrows && current_bar < ArraySize(SellArrow_Buffer) && SellArrow_Buffer[current_bar] == EMPTY_VALUE)
            {
                SellArrow_Buffer[current_bar] = current_vfi + MathAbs(current_vfi) * 0.05;
                total_signals_sell++; // ИНТЕГРАЦИЯ: Подсчет сигналов
            }
            SendAlert(ALERT_OVERBOUGHT, GetLocalizedText("vfi_overbought"), current_bar);
        }
        // Entering oversold zone
        else if(prev_vfi > dynamic_oversold_level && current_vfi <= dynamic_oversold_level)
        {
            if(ShowArrows && current_bar < ArraySize(BuyArrow_Buffer) && BuyArrow_Buffer[current_bar] == EMPTY_VALUE)
            {
                BuyArrow_Buffer[current_bar] = current_vfi - MathAbs(current_vfi) * 0.05;
                total_signals_buy++; // ИНТЕГРАЦИЯ: Подсчет сигналов
            }
            SendAlert(ALERT_OVERSOLD, GetLocalizedText("vfi_oversold"), current_bar);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Standard Deviation for inter values - IMPROVED        |
//+------------------------------------------------------------------+
double CalculateStdDev(int pos, int period)
{
    if(pos < 1 || period < 1)
        return(0.0001); // Minimum value instead of 0
    
    int actual_period = MathMin(period, pos + 1);
    int start_pos = pos - actual_period + 1;
    
    //--- calculate mean
    double mean = 0.0;
    int valid_count = 0;
    
    for(int i = start_pos; i <= pos; i++)
    {
        if(i >= 0 && i < ArraySize(inter_array))
        {
            mean += inter_array[i];
            valid_count++;
        }
    }
    
    if(valid_count == 0)
        return(0.0001);
        
    mean /= valid_count;
    
    //--- calculate variance
    double variance = 0.0;
    for(int i = start_pos; i <= pos; i++)
    {
        if(i >= 0 && i < ArraySize(inter_array))
        {
            variance += MathPow(inter_array[i] - mean, 2);
        }
    }
    variance /= valid_count;
    
    double std_dev = MathSqrt(variance);
    
    // Return minimum value if result is too small
    return(MathMax(std_dev, 0.0001));
}

//+------------------------------------------------------------------+
//| Expert deinitialization function - ИНТЕГРАЦИЯ                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    string username = GetComputerUserName(); // Используем интегрированные данные
    string current_datetime = GetCurrentDateTime(); // Используем интегрированное время
    string uptime = GetSessionUptime();
    
    // Clean up objects
    ObjectDelete(0, panel_name);
    
    // Clean up zone objects
    ObjectDelete(0, "VFI_Overbought_Zone");
    ObjectDelete(0, "VFI_Oversold_Zone");
    
    // Clean up divergence lines
    for(int i = ObjectsTotal(0, ChartWindowFind(), OBJ_TREND) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i, ChartWindowFind(), OBJ_TREND);
        if(StringFind(obj_name, "BullishDiv_") >= 0 || StringFind(obj_name, "BearishDiv_") >= 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
    
    // ИНТЕГРАЦИЯ: Расширенный отчет о завершении работы
    Print("╔══════════════════════════════════════════════════════════════════╗");
    Print("║", GetLocalizedText("indicator_finished"), "║");
    Print("╠══════════════════════════════════════════════════════════════════╣");
    Print("║ ", GetLocalizedText("reason"), ": ", reason);
    Print("║ ", GetLocalizedText("time"), ": ", current_datetime, " UTC");
    Print("║ ", GetLocalizedText("user"), ": ", username, " (Integrated)");
    Print("║ ", GetLocalizedText("runtime_uptime"), ": ", uptime);
    Print("╠══════════════════════════════════════════════════════════════════╣");
    Print("║ ", GetLocalizedText("session_stats"), ":");
    Print("║   ", GetLocalizedText("buy_signals"), ": ", total_signals_buy);
    Print("║   ", GetLocalizedText("sell_signals"), ": ", total_signals_sell);
    Print("║   ", GetLocalizedText("total_signals"), ": ", total_signals_buy + total_signals_sell);
    Print("║   Symbol: ", Symbol());
    Print("║   Timeframe: ", EnumToString(Period()));
    Print("╚══════════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Chart event handler                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Handle chart events if needed
    if(id == CHARTEVENT_CHART_CHANGE)
    {
        // Update info panel position if chart is resized
        if(ShowInfoPanel)
        {
            ChartRedraw();
        }
    }
    
    // ИНТЕГРАЦИЯ: Обработка пользовательских событий
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        // Если кликнули на информационную панель, обновить её
        if(sparam == panel_name && ShowInfoPanel)
        {
            int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
            if(current_bar > 0)
                UpdateInfoPanel(current_bar);
        }
    }
}

//+------------------------------------------------------------------+
//| Timer function - ДОПОЛНИТЕЛЬНАЯ ФУНКЦИЯ                         |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Периодическое обновление информационной панели
    if(ShowInfoPanel)
    {
        int current_bar = Bars(Symbol(), PERIOD_CURRENT) - 1;
        if(current_bar > 0)
            UpdateInfoPanel(current_bar);
    }
}
