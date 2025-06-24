class Department {
  final int id;
  final String name;
  final String description;
  final String? logo;

  Department({
    required this.id,
    required this.name,
    required this.description,
    this.logo,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      logo: json['logo']
    );
  }
}