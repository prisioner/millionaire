FactoryGirl.define do
  factory :game_question do
    # всегда одинаковое распределение ответов
    a 4
    b 3
    c 2
    d 1

    association :question
    association :game
  end
end