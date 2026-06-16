import "@typespec/http";
import "@typespec/rest";

using TypeSpec.Http;
using TypeSpec.Rest;

/**
 * Календарь бронирования.
 *
 * Роли:
 *  - Владелец календаря (один заранее заданный профиль, используется в админской части).
 *    Регистрации и авторизации в проекте нет.
 *  - Гость — бронирует слоты без создания аккаунта и без входа в систему.
 */
@service(#{ title: "Booking Calendar API" })
namespace BookingCalendar;

// ──────────────────────────────────────────────────────────────────────────
// Модели
// ──────────────────────────────────────────────────────────────────────────

/** Тип события, который создаёт владелец календаря. */
model EventType {
  /** Уникальный идентификатор типа события. */
  @key
  @visibility(Lifecycle.Read)
  id: string;

  /** Название типа события. */
  title: string;

  /** Описание типа события. */
  description: string;

  /** Длительность встречи в минутах. */
  @minValue(10)
  durationMinutes: int32;
}

/** Данные для создания типа события (id назначается сервером). */
model EventTypeCreate {
  title: string;
  description: string;

  @minValue(10)
  durationMinutes: int32;
}

/**
 * Свободный слот в окне записи.
 * Окно формируется на 14 дней, начиная с текущей даты.
 */
model Slot {
  /** Начало слота. */
  start: utcDateTime;

  /** Конец слота (start + длительность типа события). */
  end: utcDateTime;
}

/** Бронирование, созданное гостем на выбранный слот. */
model Booking {
  /** Уникальный идентификатор бронирования. */
  @key
  @visibility(Lifecycle.Read)
  id: string;

  /** Тип события, на который создано бронирование. */
  @visibility(Lifecycle.Read)
  eventTypeId: string;

  /** Начало встречи. */
  start: utcDateTime;

  /** Конец встречи. */
  @visibility(Lifecycle.Read)
  end: utcDateTime;

  /** Имя гостя. */
  guestName: string;

  /** Email гостя для связи. */
  guestEmail: string;
}

/** Данные для создания бронирования. */
model BookingCreate {
  /** Начало выбранного свободного слота. */
  start: utcDateTime;

  guestName: string;
  guestEmail: string;
}

@error
model Error {
  code: string;
  message: string;
}

/** Время уже занято другим бронированием. */
@error
model SlotTakenError {
  @statusCode statusCode: 409;
  code: "slot_taken";
  message: string;
}

// ──────────────────────────────────────────────────────────────────────────
// Эндпоинты владельца календаря (админская часть)
// ──────────────────────────────────────────────────────────────────────────

/** Управление типами событий — доступно только владельцу календаря. */
@route("/admin/event-types")
namespace OwnerEventTypes {
  /** Создать новый тип события. */
  @post
  op create(@body body: EventTypeCreate): {
    @statusCode statusCode: 201;
    @body eventType: EventType;
  };

  /** Список всех типов событий. */
  @get
  op list(): EventType[];
}

/** Предстоящие встречи — единый список бронирований всех типов событий. */
@route("/admin/bookings")
namespace OwnerBookings {
  /**
   * Страница предстоящих встреч.
   * Возвращает бронирования всех типов событий в одном списке,
   * отсортированные по времени начала.
   */
  @get
  op list(): Booking[];
}

// ──────────────────────────────────────────────────────────────────────────
// Эндпоинты гостя (публичная часть)
// ──────────────────────────────────────────────────────────────────────────

/** Просмотр доступных видов брони — публичная страница для гостя. */
@route("/event-types")
namespace GuestEventTypes {
  /** Список видов брони: название, описание и длительность. */
  @get
  op list(): EventType[];

  /** Информация о конкретном виде брони. */
  @get
  op get(@path id: string): EventType | Error;

  /**
   * Свободные слоты для выбранного типа события.
   * Слоты формируются на 14 дней, начиная с текущей даты;
   * занятые промежутки исключены (см. правило занятости).
   */
  @route("{id}/slots")
  @get
  op slots(@path id: string): Slot[] | Error;
}

/** Создание бронирования гостем. */
@route("/event-types/{eventTypeId}/bookings")
namespace GuestBookings {
  /**
   * Создать бронирование на свободный слот.
   *
   * Правило занятости: на одно и то же время нельзя создать две записи,
   * даже если это разные типы событий — в этом случае вернётся 409 SlotTakenError.
   * Слот обязан входить в окно записи (14 дней от текущей даты).
   */
  @post
  op create(
    @path eventTypeId: string,
    @body body: BookingCreate,
  ): {
    @statusCode statusCode: 201;
    @body booking: Booking;
  } | SlotTakenError | Error;
}
