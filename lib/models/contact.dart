class Contact {
  int? id;
  String name;
  String phoneNumber;

  Contact({this.id, required this.name, required this.phoneNumber});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
    };
  }

  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      name: map['name'],
      phoneNumber: map['phoneNumber'],
    );
  }
}
