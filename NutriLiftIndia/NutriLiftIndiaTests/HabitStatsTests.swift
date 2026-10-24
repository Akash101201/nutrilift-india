import XCTest
@testable import NutriLiftIndia

final class HabitStatsTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let now = date(2026, 10, 24)
        let logged = [date(2026, 10, 24, hour: 8), date(2026, 10, 23), date(2026, 10, 22), date(2026, 10, 20)]
        XCTAssertEqual(HabitStats.currentStreak(loggedDates: logged, now: now, calendar: calendar), 3)
    }

    func testStreakSurvivesUntilEndOfTodayIfYesterdayWasLogged() {
        let now = date(2026, 10, 24)
        let logged = [date(2026, 10, 23), date(2026, 10, 22)]
        XCTAssertEqual(HabitStats.currentStreak(loggedDates: logged, now: now, calendar: calendar), 2)
    }

    func testStreakBreaksAfterAMissedDay() {
        let now = date(2026, 10, 24)
        let logged = [date(2026, 10, 22), date(2026, 10, 21)]
        XCTAssertEqual(HabitStats.currentStreak(loggedDates: logged, now: now, calendar: calendar), 0)
    }

    func testStreakIgnoresMultipleEntriesOnTheSameDay() {
        let now = date(2026, 10, 24)
        let logged = [date(2026, 10, 24, hour: 8), date(2026, 10, 24, hour: 13), date(2026, 10, 24, hour: 20)]
        XCTAssertEqual(HabitStats.currentStreak(loggedDates: logged, now: now, calendar: calendar), 1)
    }

    func testEmptyLogHasNoStreak() {
        XCTAssertEqual(HabitStats.currentStreak(loggedDates: [], now: date(2026, 10, 24), calendar: calendar), 0)
    }

    func testLoggedToday() {
        let now = date(2026, 10, 24)
        XCTAssertTrue(HabitStats.loggedToday(loggedDates: [date(2026, 10, 24, hour: 6)], now: now, calendar: calendar))
        XCTAssertFalse(HabitStats.loggedToday(loggedDates: [date(2026, 10, 23)], now: now, calendar: calendar))
    }

    func testWaterTotalOnlyCountsTheGivenDay() {
        let now = date(2026, 10, 24)
        let entries = [
            WaterLogEntry(date: date(2026, 10, 24, hour: 9), amountMl: 250),
            WaterLogEntry(date: date(2026, 10, 24, hour: 15), amountMl: 500),
            WaterLogEntry(date: date(2026, 10, 23), amountMl: 1000),
        ]
        XCTAssertEqual(HabitStats.waterTotalMl(entries: entries, on: now, calendar: calendar), 750)
    }
}
