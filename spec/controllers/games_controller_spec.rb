require 'rails_helper'
require 'support/my_spec_helper'

RSpec.describe GamesController, type: :controller do
  let(:user) { FactoryGirl.create(:user) }
  let(:admin) { FactoryGirl.create(:user, is_admin: true) }
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  context 'Anon' do
    it 'kick from #show' do
      get :show, id: game_w_questions.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to new_user_session_path
      expect(flash[:alert]).to be
    end

    it 'kick from #create' do
      generate_questions(15)

      post :create
      game = assigns(:game)

      expect(game).to be_nil

      expect(response.status).not_to eq 200
      expect(response).to redirect_to new_user_session_path
      expect(flash[:alert]).to be
    end

    it 'kick from #answer' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key

      # перезагружаем игру
      game_w_questions.reload

      # убеждаемся, что уровень игры не изменился
      expect(game_w_questions.current_level).to be_zero

      expect(response.status).not_to eq 200
      expect(response).to redirect_to new_user_session_path
      expect(flash[:alert]).to be
    end

    it 'kick from #take_money' do
      put :take_money, id: game_w_questions.id

      # перезагружаем игру
      game_w_questions.reload

      # убеждаемся, что игра не закончилась
      expect(game_w_questions).not_to be_finished

      expect(response.status).not_to eq 200
      expect(response).to redirect_to new_user_session_path
      expect(flash[:alert]).to be
    end
  end

  context 'Usual user' do
    before(:each) { sign_in user }

    it 'creates game' do
      generate_questions(15)

      post :create
      game = assigns(:game)

      expect(game).not_to be_finished
      expect(game.user).to eq(user)

      expect(response).to redirect_to game_path(game)
      expect(flash[:notice]).to be
    end

    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game)
      expect(game).not_to be_finished
      expect(game.user).to eq user

      expect(response.status).to eq(200)
      expect(response).to render_template :show
    end

    it 'answers correct' do
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game).not_to be_finished
      expect(game.current_level).to be_positive
      expect(response).to redirect_to game_path(game)
      expect(flash).to be_empty
    end

    it 'answer wrong' do
      q = game_w_questions.current_game_question
      answers = %w(a b c d)
      wrong_answers = answers.reject { |a| a == q.correct_answer_key }

      put :answer, id: game_w_questions.id, letter: wrong_answers.sample

      game = assigns(:game)

      expect(game).to be_finished
      expect(game.status).to eq :fail
      expect(game.current_level).to eq 0
      expect(response).to redirect_to user_path(user)
      expect(flash[:alert]).to be
    end

    it '#show alien game' do
      alien_game = FactoryGirl.create(:game_with_questions)

      get :show, id: alien_game.id

      expect(response.status).not_to eq 200
      expect(response).to redirect_to root_path
      expect(flash[:alert]).to be
    end

    it 'takes money' do
      game_w_questions.update_attribute(:current_level, 7)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)
      expect(game).to be_finished
      expect(game.prize).to eq 4000

      user.reload
      expect(user.balance).to eq 4000

      expect(response).to redirect_to user_path(user)
      expect(flash[:warning]).to be
    end

    it 'try to create second game' do
      expect(game_w_questions).not_to be_finished

      expect { post :create }.not_to change(Game, :count)

      game = assigns(:game)
      expect(game).to be_nil

      expect(response).to redirect_to game_path(game_w_questions)
      expect(flash[:alert]).to be
    end

    it 'uses audience help' do
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      expect(game).not_to be_finished
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses fifty_fifty help' do
      expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
      expect(game_w_questions.fifty_fifty_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :fifty_fifty
      game = assigns(:game)
      key = game_w_questions.current_game_question.correct_answer_key

      expect(game).not_to be_finished
      expect(game.fifty_fifty_used).to be_truthy
      expect(game.current_game_question.help_hash[:fifty_fifty]).to be
      expect(game.current_game_question.help_hash[:fifty_fifty]).to include(key)
      expect(response).to redirect_to(game_path(game))
    end

    it 'uses friend_call help' do
      expect(game_w_questions.current_game_question.help_hash[:friend_call]).not_to be
      expect(game_w_questions.friend_call_used).to be_falsey

      put :help, id: game_w_questions.id, help_type: :friend_call
      game = assigns(:game)

      expect(game).not_to be_finished
      expect(game.friend_call_used).to be_truthy
      expect(game.current_game_question.help_hash[:friend_call]).to be
      expect(response).to redirect_to(game_path(game))
    end
  end
end
