import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

class ContactRepositoryImpl extends ContactRepository {
  final Map<String, ContactModel> _store = {};

  @override
  Future<void> create(Contact contact) async {
    _store[contact.id] = ContactModel.fromContact(contact);
    addToStream(
        ContactChangeInfo(type: ContactChangeType.create, contacts: [contact]));
  }

  @override
  Future<void> readMore([bool refresh = true]) async {
    await _getContactsFromStore();
  }

  @override
  Future<void> update(Contact contact) async {
    _store[contact.id] = ContactModel.fromContact(contact);
    addToStream(
        ContactChangeInfo(type: ContactChangeType.update, contacts: [contact]));
  }

  @override
  Future<void> delete(Contact contact) async {
    _store.remove(contact.id);
    addToStream(
        ContactChangeInfo(type: ContactChangeType.delete, contacts: [contact]));
  }

  Future<void> _getContactsFromStore() async {
    List<Contact> contactList =
        _store.entries.map((e) => e.value.toContact()).toList();
    addToStream(ContactChangeInfo(
        type: ContactChangeType.read,
        contacts: contactList,
        totalCount: contactList.length));
  }
}

class ContactModel extends Equatable {
  final String id;
  final DateTime created;
  final DateTime modified;
  final String firstname;
  final String lastname;
  final int age;
  final bool favourite;

  ContactModel({
    String? id,
    DateTime? created,
    DateTime? modified,
    required this.firstname,
    required this.lastname,
    required this.age,
    required this.favourite,
  })  : id = id ?? const Uuid().v4(),
        created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now();

  Contact toContact() {
    return Contact(
      id: id,
      created: created,
      modified: modified,
      firstname: firstname,
      lastname: lastname,
      age: age,
      favourite: favourite,
    );
  }

  static ContactModel fromContact(Contact contact) {
    return ContactModel(
      id: contact.id,
      created: contact.created,
      modified: contact.modified,
      firstname: contact.firstname,
      lastname: contact.lastname,
      age: contact.age,
      favourite: contact.favourite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'firstname': firstname,
      'lastname': lastname,
      'age': age,
      'favourite': favourite,
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      firstname: map['firstname'],
      lastname: map['lastname'],
      age: map['age'],
      favourite: map['favourite'],
    );
  }

  String toJson() => json.encode(toMap());

  factory ContactModel.fromJson(String source) =>
      ContactModel.fromMap(json.decode(source));

  @override
  List<Object> get props => [
        firstname,
        lastname,
        age,
        favourite,
      ];
}

// CRUD Repo based on a stream
abstract class ContactRepository {
  late Future ready;

  final _controller = StreamController<ContactChangeInfo>();
  Stream<ContactChangeInfo>? _stream;

  void addToStream(ContactChangeInfo changeInfo) =>
      _controller.sink.add(changeInfo);
  void addErrorToStream(Object error) => _controller.sink.addError(error);

  Future<void> create(Contact contact);

  Stream<ContactChangeInfo> read() =>
      _stream ??= _controller.stream.asBroadcastStream();

  Future<void> readMore([bool refresh = false]);

  Future<void> update(Contact contact);

  Future<void> delete(Contact contact);
}

enum ContactChangeType { create, read, update, delete }

class ContactChangeInfo extends Equatable {
  final ContactChangeType type;
  final List<Contact> contacts;
  final int totalCount;
  const ContactChangeInfo(
      {required this.type, required this.contacts, this.totalCount = 0});

  @override
  List<Object?> get props => [type, contacts, totalCount];
}

class Contact extends Equatable {
  final String id;
  final DateTime created;
  final DateTime modified;

  final String firstname;
  final String lastname;
  final int age;
  final bool favourite;

  Contact({
    String? id,
    DateTime? created,
    DateTime? modified,
    required this.firstname,
    required this.lastname,
    required this.age,
    required this.favourite,
  })  : id = id ?? const Uuid().v4(),
        created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now();

  @override
  List<Object> get props => [
        id,
        created,
        modified,
        firstname,
        lastname,
        age,
        favourite,
      ];

  @override
  String toString() {
    return '(id: $id,  firstname: $firstname, lastname: $lastname, age: $age, favourite: $favourite, )';
  }

  Contact copyWith({
    String? id,
    DateTime? created,
    DateTime? modified,
    String? firstname,
    String? lastname,
    int? age,
    bool? favourite,
  }) {
    return Contact(
      id: id ?? this.id,
      created: created ?? DateTime.now(),
      modified: modified ?? DateTime.now(),
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      age: age ?? this.age,
      favourite: favourite ?? this.favourite,
    );
  }
}

class ContactEditView extends StatelessWidget {
  static Key topLeftButtonKey = const Key('contact-close-button');
  static Key bottomLeftButtonKey = const Key('contact-delete-button');
  static Key bottomRightButtonKey = const Key('contact-submit-button');

  final Contact? entity;
  final ContactEditBloc? bloc;

  const ContactEditView({super.key, this.entity, this.bloc});

  static MaterialPageRoute route([Contact? entity]) {
    return MaterialPageRoute(
      builder: (context) => ContactEditView(entity: entity),
      settings: RouteSettings(name: '/editContact', arguments: [entity]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) =>
            bloc ?? ContactEditBloc(context.read<ContactRepository>(), entity),
        child: Builder(builder: (context) {
          return BlocConsumer<ContactEditBloc, ContactEditState>(
            listener: (context, state) {
              if (state.status == ContactEditStatus.success) {
                Navigator.of(context).pop(state.contact);
              }
            },
            builder: (context, state) {
              return Scaffold(
                appBar: AppBar(
                  title:
                      Text('${entity == null ? "Create" : "Update"} Contact'),
                  leading: IconButton(
                    key: ContactEditView.topLeftButtonKey,
                    onPressed: () {
                      Navigator.of(context).pop<bool>(false);
                    },
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: const [
                        _FirstnameField(),
                        _LastnameField(),
                        _AgeField(),
                        _FavouriteField(),
                      ],
                    ),
                  ),
                ),
                floatingActionButton: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    entity != null
                        ? FloatingActionButton(
                            heroTag: null,
                            backgroundColor: Colors.red.shade300,
                            key: ContactEditView.bottomLeftButtonKey,
                            child: const Icon(Icons.delete),
                            onPressed: () => context
                                .read<ContactEditBloc>()
                                .add(ContactEditEventDelete()),
                          )
                        : Container(),
                    const SizedBox(width: 10),
                    FloatingActionButton(
                      backgroundColor: Colors.green,
                      key: ContactEditView.bottomRightButtonKey,
                      child: const Icon(Icons.check),
                      onPressed: () => context
                          .read<ContactEditBloc>()
                          .add(ContactEditEventSubmitted()),
                    ),
                  ],
                ),
              );
            },
          );
        }));
  }
}

class _FirstnameField extends StatelessWidget {
  const _FirstnameField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactEditBloc>().state;
    final hintText = state.contact?.firstname ?? 'Scott';

    return TextFormField(
      autofocus: true,
      key: const Key('edit-firstname-field'),
      initialValue: state.firstname.toString(),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Firstname',
        hintText: hintText.toString(),
      ),
      maxLength: 255,
      onChanged: (value) {
        context
            .read<ContactEditBloc>()
            .add(ContactEditEventFirstnameChanged(toType('String', value, '')));
      },
      onEditingComplete: () =>
          context.read<ContactEditBloc>().add(ContactEditEventSubmitted()),
    );
  }
}

class _LastnameField extends StatelessWidget {
  const _LastnameField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactEditBloc>().state;
    final hintText = state.contact?.lastname ?? 'Horn';

    return TextFormField(
      autofocus: true,
      key: const Key('edit-lastname-field'),
      initialValue: state.lastname.toString(),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Lastname',
        hintText: hintText.toString(),
      ),
      maxLength: 255,
      onChanged: (value) {
        context
            .read<ContactEditBloc>()
            .add(ContactEditEventLastnameChanged(toType('String', value, '')));
      },
      onEditingComplete: () =>
          context.read<ContactEditBloc>().add(ContactEditEventSubmitted()),
    );
  }
}

class _AgeField extends StatelessWidget {
  const _AgeField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactEditBloc>().state;
    final hintText = state.contact?.age ?? 21;

    return TextFormField(
      autofocus: true,
      key: const Key('edit-age-field'),
      initialValue: state.age.toString(),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Age',
        hintText: hintText.toString(),
      ),
      maxLength: 255,
      onChanged: (value) {
        context
            .read<ContactEditBloc>()
            .add(ContactEditEventAgeChanged(toType('int', value, 0)));
      },
      onEditingComplete: () =>
          context.read<ContactEditBloc>().add(ContactEditEventSubmitted()),
    );
  }
}

class _FavouriteField extends StatelessWidget {
  const _FavouriteField({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ContactEditBloc>().state;
    final hintText = state.contact?.favourite ?? true;

    return TextFormField(
      autofocus: true,
      key: const Key('edit-favourite-field'),
      initialValue: state.favourite.toString(),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Favourite',
        hintText: hintText.toString(),
      ),
      maxLength: 255,
      onChanged: (value) {
        context.read<ContactEditBloc>().add(
            ContactEditEventFavouriteChanged(toType('bool', value, false)));
      },
      onEditingComplete: () =>
          context.read<ContactEditBloc>().add(ContactEditEventSubmitted()),
    );
  }
}

dynamic toType(String type, String value, dynamic emptyValue) {
  switch (type) {
    case 'int':
      try {
        return int.parse(value);
      } catch (e) {
        return emptyValue;
      }
    case 'bool':
      return value.toLowerCase().endsWith('true');
    default:
      return value;
  }
}

class ContactReadView extends StatefulWidget {
  static Key topLeftButtonKey = const Key('contact-home-button');
  static Key topRightButtonKey = const Key('contact-refresh-button');
  static Key bottomRightButtonKey = const Key('contact-done-button');
  static Key deleteButtonKey(id) => Key('contact-$id-delete-button');

  final ContactReadBloc? bloc;

  const ContactReadView({super.key, this.bloc});

  static MaterialPageRoute route([ContactReadBloc? bloc]) {
    return MaterialPageRoute(
      builder: (context) => ContactReadView(bloc: bloc),
      settings: const RouteSettings(name: '/readContact'),
    );
  }

  @override
  State<ContactReadView> createState() => _ContactReadViewState();
}

class _ContactReadViewState extends State<ContactReadView> {
  List<Contact> _list = [];
  int _totalCount = 0;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          widget.bloc ?? ContactReadBloc(context.read<ContactRepository>()),
      child: Builder(builder: (context) {
        ContactReadBloc bloc = context.read<ContactReadBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contact List'),
            leading: IconButton(
              key: ContactReadView.topLeftButtonKey,
              onPressed: () {
                Navigator.of(context).pop<bool>(false);
              },
              icon: const Icon(
                Icons.home,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                    key: ContactReadView.topRightButtonKey,
                    onPressed: () => bloc.add(const ContactReadEventReload()),
                    icon: const Icon(Icons.refresh)),
              )
            ],
          ),
          body: BlocBuilder<ContactReadBloc, ContactReadState>(
            builder: (context, state) {
              switch (state.runtimeType) {
                case ContactReadStateCreate:
                  _list.add(state.selectedContact!);
                  _totalCount++;
                  break;
                case ContactReadStateUpdate:
                  final selected = state.selectedContact!;
                  var toUpdate =
                      _list.firstWhere((element) => selected.id == element.id);
                  _list[_list.indexOf(toUpdate)] = selected;
                  break;
                case ContactReadStateDelete:
                  final selected = state.selectedContact!;
                  _list.retainWhere((element) => element.id != selected.id);
                  _totalCount--;
                  break;
                case ContactReadStateFailure:
                  return _errorWidget(state.message);
                case ContactReadStateInitial:
                case ContactReadStateLoading:
                  return _loadingWidget();
                case ContactReadStateSuccess:
                  _list = [...state.contacts];
                  _totalCount = state.totalCount;
                  break;
                default:
              }
              return _listWidget(bloc, state);
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.green,
            key: ContactReadView.bottomRightButtonKey,
            child: const Icon(Icons.add),
            onPressed: () => _create(),
          ),
        );
      }),
    );
  }

  Widget _listWidget(bloc, state) {
    return ListTable<Contact>(
      totalCount: _totalCount,
      cacheCount: _list.length,
      columns: const ['Firstname', 'Lastname', 'Age', 'Favourite', ''],
      cache: _list,
      renderRow: (entity) => [
        ...[
          entity.firstname.toString(),
          entity.lastname.toString(),
          entity.age.toString(),
          entity.favourite.toString(),
        ].map((e) => Text(e)),
        IconButton(
          key: ContactReadView.deleteButtonKey(entity.id),
          icon: Icon(Icons.delete, color: Colors.red.shade300),
          onPressed: () => bloc.add(ContactReadEventDelete(entity)),
        )
      ],
      readMore: () => bloc.add(const ContactReadEventReadMore()),
      edit: (entity) => _edit(entity),
    );
    // return ListView.builder(
    //   controller: _scrollController,
    //   itemCount: _list.length == _totalCount ? _totalCount : _list.length + 1,
    //   itemBuilder: (context, index) {
    //     if (index == _list.length) {
    //       Future.delayed(
    //           Duration.zero,
    //           () => bloc.add(const ContactReadEventReadMore()),
    //       );
    //       return const Center(
    //         child: CircularProgressIndicator(),
    //       );
    //     } else {
    //       var entity = _list[index];
    //       return ContactWidget(
    //         entity: entity,
    //         key: ValueKey(entity.id),
    //         focusScopeNode: _node,
    //         onDelete: () => bloc.add(ContactReadEventDelete(entity)),
    //         onEdit: () => _edit(entity),
    //       );
    //     }
    //   },
    // );
  }

  void _create() {
    Navigator.of(context).push(ContactEditView.route());
  }

  void _edit(contact) {
    Navigator.of(context).push(ContactEditView.route(contact));
  }

  Widget _loadingWidget() {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _errorWidget(String message) {
    return Center(
      child: SizedBox(
        width: 400,
        height: 200,
        child: Column(
          children: [
            Text(message, softWrap: true),
          ],
        ),
      ),
    );
  }
}

class ContactWidget extends StatelessWidget {
  final Contact entity;
  final FocusScopeNode focusScopeNode;
  final void Function()? onEdit;
  final void Function()? onDelete;
  const ContactWidget({
    super.key,
    required this.entity,
    required this.focusScopeNode,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
          '${entity.firstname} ${entity.lastname} ${entity.age} ${entity.favourite} '),
      trailing: onDelete != null
          ? IconButton(
              key: Key('contact-${entity.id}-delete-button'),
              icon: Icon(Icons.delete, color: Colors.red.shade300),
              onPressed: onDelete,
            )
          : null,
      onTap: onEdit,
    );
  }
}

abstract class ContactEditEvent extends Equatable {
  const ContactEditEvent();
}

class ContactEditEventFirstnameChanged extends ContactEditEvent {
  final String firstname;
  const ContactEditEventFirstnameChanged(
    this.firstname,
  );

  @override
  List<Object?> get props => [firstname];
}

class ContactEditEventLastnameChanged extends ContactEditEvent {
  final String lastname;
  const ContactEditEventLastnameChanged(
    this.lastname,
  );

  @override
  List<Object?> get props => [lastname];
}

class ContactEditEventAgeChanged extends ContactEditEvent {
  final int age;
  const ContactEditEventAgeChanged(
    this.age,
  );

  @override
  List<Object?> get props => [age];
}

class ContactEditEventFavouriteChanged extends ContactEditEvent {
  final bool favourite;
  const ContactEditEventFavouriteChanged(
    this.favourite,
  );

  @override
  List<Object?> get props => [favourite];
}

class ContactEditEventSubmitted extends ContactEditEvent {
  @override
  List<Object?> get props => [];
}

class ContactEditEventDelete extends ContactEditEvent {
  @override
  List<Object?> get props => [];
}

class ContactEditBloc extends Bloc<ContactEditEvent, ContactEditState> {
  final ContactRepository _repo;
  ContactEditBloc(this._repo, [Contact? entity])
      : super(ContactEditState(
          contact: entity,
          firstname: entity?.firstname ?? '',
          lastname: entity?.lastname ?? '',
          age: entity?.age ?? 0,
          favourite: entity?.favourite ?? false,
        )) {
    on<ContactEditEventFirstnameChanged>(_firstnameChanged);
    on<ContactEditEventLastnameChanged>(_lastnameChanged);
    on<ContactEditEventAgeChanged>(_ageChanged);
    on<ContactEditEventFavouriteChanged>(_favouriteChanged);
    on<ContactEditEventSubmitted>(_submitted);
    on<ContactEditEventDelete>(_delete);
  }

  FutureOr<void> _firstnameChanged(ContactEditEventFirstnameChanged event,
      Emitter<ContactEditState> emit) async {
    emit(state.copyWith(firstname: event.firstname));
  }

  FutureOr<void> _lastnameChanged(ContactEditEventLastnameChanged event,
      Emitter<ContactEditState> emit) async {
    emit(state.copyWith(lastname: event.lastname));
  }

  FutureOr<void> _ageChanged(
      ContactEditEventAgeChanged event, Emitter<ContactEditState> emit) async {
    emit(state.copyWith(age: event.age));
  }

  FutureOr<void> _favouriteChanged(ContactEditEventFavouriteChanged event,
      Emitter<ContactEditState> emit) async {
    emit(state.copyWith(favourite: event.favourite));
  }

  FutureOr<void> _submitted(
      ContactEditEventSubmitted event, Emitter<ContactEditState> emit) async {
    Contact entity;
    if (state.contact == null) {
      entity = Contact(
        firstname: state.firstname,
        lastname: state.lastname,
        age: state.age,
        favourite: state.favourite,
      );
      await _repo.create(entity);
    } else {
      entity = state.contact!.copyWith(
        firstname: state.firstname,
        lastname: state.lastname,
        age: state.age,
        favourite: state.favourite,
      );
      await _repo.update(entity);
    }
    emit(state.copyWith(
        initialContact: entity, status: ContactEditStatus.success));
  }

  FutureOr<void> _delete(
      ContactEditEventDelete event, Emitter<ContactEditState> emit) async {
    await _repo.delete(state.contact!);
    emit(state.copyWith(
        initialContact: state.contact!, status: ContactEditStatus.success));
  }
}

enum ContactEditStatus { initial, loading, success, failure }

class ContactEditState extends Equatable {
  final ContactEditStatus status;
  final Contact? contact;
  final String firstname;
  final String lastname;
  final int age;
  final bool favourite;

  const ContactEditState({
    this.status = ContactEditStatus.initial,
    this.contact,
    required this.firstname,
    required this.lastname,
    required this.age,
    required this.favourite,
  });

  @override
  List<Object?> get props => [
        status,
        contact,
        firstname,
        lastname,
        age,
        favourite,
      ];

  ContactEditState copyWith({
    ContactEditStatus? status,
    Contact? initialContact,
    String? firstname,
    String? lastname,
    int? age,
    bool? favourite,
  }) {
    return ContactEditState(
      status: status ?? this.status,
      contact: initialContact ?? contact,
      firstname: firstname ?? this.firstname,
      lastname: lastname ?? this.lastname,
      age: age ?? this.age,
      favourite: favourite ?? this.favourite,
    );
  }
}

abstract class ContactReadEvent {
  const ContactReadEvent();
}

class ContactReadEventCreate extends ContactReadEvent {
  const ContactReadEventCreate();
}

class ContactReadEventSubscribe extends ContactReadEvent {
  const ContactReadEventSubscribe();
}

class ContactReadEventReload extends ContactReadEvent {
  const ContactReadEventReload();
}

class ContactReadEventReadMore extends ContactReadEvent {
  const ContactReadEventReadMore();
}

class ContactReadEventUpdate extends ContactReadEvent {
  final Contact contact;
  const ContactReadEventUpdate(this.contact);
}

class ContactReadEventDelete extends ContactReadEvent {
  final Contact contact;
  const ContactReadEventDelete(this.contact);
}

class ContactReadBloc extends Bloc<ContactReadEvent, ContactReadState> {
  final ContactRepository _repo;
  ContactReadBloc(this._repo) : super(ContactReadStateInitial()) {
    on<ContactReadEventSubscribe>(_eventSubscribe);
    on<ContactReadEventReload>(_eventReload);
    on<ContactReadEventReadMore>(_eventReadMore);
    on<ContactReadEventCreate>(_eventAdd);
    on<ContactReadEventDelete>(_eventDelete);
    on<ContactReadEventUpdate>(_eventUpdate);

    // Subscribe to reactive repo and then laod
    add(const ContactReadEventSubscribe());
    add(const ContactReadEventReload());
  }

  _eventSubscribe(
      ContactReadEventSubscribe event, Emitter<ContactReadState> emit) async {
    await emit.forEach<ContactChangeInfo>(
      _repo.read(),
      onData: (info) {
        switch (info.type) {
          case ContactChangeType.create:
            return ContactReadStateCreate(selectedContact: info.contacts.first);
          case ContactChangeType.read:
            return ContactReadStateSuccess(
              contacts: info.contacts,
              totalCount: info.totalCount,
            );
          case ContactChangeType.update:
            return ContactReadStateUpdate(selectedContact: info.contacts.first);
          case ContactChangeType.delete:
            return ContactReadStateDelete(selectedContact: info.contacts.first);
        }
      },
      onError: (error, stackTrace) =>
          ContactReadStateFailure(message: '$error'),
    );
  }

  _eventReload(
      ContactReadEventReload event, Emitter<ContactReadState> emit) async {
    emit(ContactReadStateLoading());
    _repo.readMore(true);
  }

  _eventReadMore(
      ContactReadEventReadMore event, Emitter<ContactReadState> emit) async {
    _repo.readMore();
  }

  _eventDelete(
      ContactReadEventDelete event, Emitter<ContactReadState> emit) async {
    _repo.delete(event.contact);
  }

  _eventUpdate(
      ContactReadEventUpdate event, Emitter<ContactReadState> emit) async {
    _repo.update(event.contact);
  }

  _eventAdd(ContactReadEventCreate event, Emitter<ContactReadState> emit) {
    _repo.create(Contact(
      firstname: '',
      lastname: '',
      age: 0,
      favourite: false,
    ));
  }
}

abstract class ContactReadState extends Equatable {
  final Contact? selectedContact;
  final List<Contact> contacts;
  final String message;
  final int totalCount;
  const ContactReadState(
      {this.contacts = const [],
      this.message = '',
      this.selectedContact,
      this.totalCount = 0});

  @override
  List<Object?> get props => [selectedContact, contacts, message, totalCount];
}

class ContactReadStateInitial extends ContactReadState {}

class ContactReadStateLoading extends ContactReadState {}

class ContactReadStateSuccess extends ContactReadState {
  const ContactReadStateSuccess({super.contacts, super.totalCount});
}

class ContactReadStateCreate extends ContactReadState {
  const ContactReadStateCreate({super.selectedContact});
}

class ContactReadStateUpdate extends ContactReadState {
  const ContactReadStateUpdate({super.selectedContact});
}

class ContactReadStateDelete extends ContactReadState {
  const ContactReadStateDelete({super.selectedContact});
}

class ContactReadStateFailure extends ContactReadState {
  const ContactReadStateFailure({super.message});
}

class ListTable<T> extends StatelessWidget {
  final int totalCount;
  final int cacheCount;
  final List<String> columns;
  final List<T> cache;
  final List<Widget> Function(T entity) renderRow;
  final Future Function() readMore;
  final Function(T entity) edit;

  const ListTable({
    Key? key,
    required this.totalCount,
    required this.cacheCount,
    required this.columns,
    required this.cache,
    required this.renderRow,
    required this.readMore,
    required this.edit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(0), children: [
      PaginatedDataTable(
        showCheckboxColumn: false,
        rowsPerPage: 10,
        columns: columns.map((e) => DataColumn(label: Text(e))).toList(),
        source: _DataSource(
          rowCount: cacheCount == totalCount ? totalCount : cacheCount + 1,
          rowBuilder: (index) {
            if (index == cacheCount) {
              Future.delayed(Duration.zero, readMore);
              return DataRow(cells: [
                const DataCell(CircularProgressIndicator()),
                ...List.filled(columns.length - 1, DataCell(Container())),
              ]);
            } else {
              var entity = cache[index];
              int cell = 0;
              return DataRow(
                key: ObjectKey(entity),
                onSelectChanged: (value) => edit(entity),
                cells: renderRow(entity).map((e) {
                  return cell++ == 0
                      ? DataCell(Container(key: ObjectKey(entity), child: e))
                      : DataCell(e);
                }).toList(),
              );
            }
          },
        ),
      )
    ]);
  }
}

class _DataSource extends DataTableSource {
  final DataRow? Function(int index) rowBuilder;

  @override
  final int rowCount;

  _DataSource({required this.rowBuilder, required this.rowCount});

  @override
  DataRow? getRow(int index) => rowBuilder(index);

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => -1;
}

void main(List<String> args) async => runApp(appWidget());

class App extends StatelessWidget {
  final NavigatorObserver? navigatorObserver;
  const App({super.key, this.navigatorObserver});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: navigatorObserver != null ? [navigatorObserver!] : [],
      debugShowCheckedModeBanner: false,
      title: 'Scaffold App',
      home: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(title: const Text('Features')),
          body: ListView(children: [
            ListTile(
              key: const Key('contact-feature-tile'),
              leading: const Icon(Icons.view_list, color: Colors.green),
              horizontalTitleGap: 0,
              title: const Text('Contact'),
              onTap: () => Navigator.of(context).push(ContactReadView.route()),
            ),
          ]),
        );
      }),
    );
  }
}

Widget appWidget() {
  final repoContact = ContactRepositoryImpl();
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<ContactRepository>.value(
        value: repoContact,
      ),
    ],
    child: const App(),
  );
}
